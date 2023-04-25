require "./options"

module Toshi::Api
  macro included
    extend Toshi::Api::ClassMethods
    alias Options = Toshi::Api::Options

    @@logger = ::Log.for({{@type.name.id}})

    def logger
      @@logger
    end

    def self.logger
      @@logger
    end

    def options
      @@options
    end

    def pool
      @@pool
    end
  end

  macro define_api(host, scheme = "https", port = nil, prefix = nil, tls_verify_mode = OpenSSL::SSL::VerifyMode::PEER, default_headers = HTTP::Headers{
                     "Content-Type" => "application/json",
                     "Accept"       => "application/json",
                   }, pool_capacity = 200, initial_pool_size = 20, pool_timeout = 0.1, sleep_time = 0.0)

    class_getter options : Options = self.default_options
    class_getter pool : DB::Pool(HTTP::Client) = self._create_pool

    private def self.default_options : Options
      Options.new(
        {{host}}, {{scheme}}, {{port}}, {{prefix}}, {{tls_verify_mode}}, {{default_headers}},
        {{pool_capacity}}, {{initial_pool_size}}, {{pool_timeout}}, {{sleep_time}},
      )
    end

    # Will create a new pool of clients
    private def self._create_pool : DB::Pool(HTTP::Client)
      DB::Pool(HTTP::Client).new(max_pool_size: self.options.pool_capacity, initial_pool_size: self.options.initial_pool_size, checkout_timeout: self.options.pool_timeout) do
        self._create_client
      end
    end

    # Will create a new client
    private def self._create_client : HTTP::Client
      tls_client = OpenSSL::SSL::Context::Client.new.tap do |ctx|
        ctx.verify_mode = self.options.tls_verify_mode
      end
      HTTP::Client.new(URI.new(scheme: self.options.scheme, host: self.options.host, port: self.options.port), tls: tls_client)
    end
  end

  module ClassMethods
    abstract def _create_client : HTTP::Client
    abstract def _create_pool : DB::Pool(HTTP::Client)
    abstract def default_options : Options
    abstract def options : Options
    abstract def pool : DB::Pool(HTTP::Client)
    abstract def logger

    def configure(_options : Options? = nil, &block)
      opts = (_options || self.default_options)
      yield opts
      configure(opts)
      self
    end

    def configure(_options : Options? = nil)
      @@options = (_options || self.default_options)

      begin
        logger.trace { "Closing pool" }
        self.pool.close
      rescue ex : Exception
        logger.error { ex.message }
        logger.trace(exception: ex) { ex.message }
      end
      @@pool = self._create_pool

      self
    end

    # Will check out a connection from the pool and yield it to the block
    private def using_connection
      self.pool.retry do
        self.pool.checkout do |conn|
          yield conn
        rescue ex : IO::Error | IO::TimeoutError
          logger.error { ex.message }
          logger.trace(exception: ex) { ex.message }
          raise Toshi::Error::ConnectionLost.new(conn)
        end
      end
    end

    # URI helper function
    def make_request_uri(path : String, params : String | Nil = nil) : URI
      _path = File.join(self.options.prefix || "", path)
      if _path[0] != '/'
        _path = '/' + _path
      end
      URI.new(path: _path, query: params)
    end

    # Make a request with a string URI
    def make_request(path : String, params : String | Nil = nil)
      make_request(make_request_uri(path, params))
    end

    # Make a request with a URI object
    def make_request(uri : URI)
      sleep(self.options.sleep_time) if self.options.sleep_time > 0
      logger.debug { "GET: #{uri}" }
      using_connection do |client|
        resp = client.get(uri.to_s, headers: self.options.default_headers)
        if resp.success?
          resp.body
        elsif resp.status_code == 404
          raise Error::NotFound.new(resp.body, resp.status_code)
        else
          raise Error.new(resp.body, resp.status_code)
        end
      end
    end
  end
end

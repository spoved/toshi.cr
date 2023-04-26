require "../options"

module Toshi::Api
  module ClassMethods
    abstract def _create_client : HTTP::Client
    abstract def _create_pool : DB::Pool(HTTP::Client)
    abstract def default_options : Options
    abstract def options : Options
    abstract def pool : DB::Pool(HTTP::Client)
    abstract def logger

    # Configure the API client
    #
    # ```
    # MyApi.configure do |opts|
    #   opts.host = "localhost"
    #   opts.port = 5000
    #   opts.prefix = "api/v0"
    #   opts.default_headers = {"User-Agent" => "Toshi-Ruby-Client"}
    #   opts.sleep_time = 0.1
    # end
    # ```
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

    # Generic method for making a request with params and headers
    def _request(path : String, method = "GET", params = nil, headers = nil, body : String | JSON::Serializable | NamedTuple | Nil = nil)
      uri = make_request_uri(path, params)
      _body = case body
              when NamedTuple, JSON::Serializable
                body.to_json
              else
                body
              end
      _request(uri, method, headers, _body)
    end

    # Generic method for making a request with a URI and headers
    def _request(uri : URI, method = "GET", headers = nil, body : String? = nil)
      if headers.nil?
        headers = self.options.default_headers
      else
        headers = self.options.default_headers.clone.merge!(headers)
      end

      logger.debug &.emit("Performing request", method: method, uri: uri.to_s,
        headers: headers.to_s, body: body, sleep_time: self.options.sleep_time)

      sleep(self.options.sleep_time) if self.options.sleep_time > 0

      using_connection do |client|
        resp = client.exec(method, path: uri.to_s, headers: headers, body: body)
        logger.trace { "Response: #{resp.status_code} #{resp.body}" }
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

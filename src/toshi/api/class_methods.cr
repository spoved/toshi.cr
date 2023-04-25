require "../options"

module Toshi::Api
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

    # Generic method for making a request with params and headers
    def _request(path : String, method = "GET", params = nil, headers = nil, body = nil)
      uri = make_request_uri(path, params)
      _request(uri, method, headers, body)
    end

    def _request(uri : URI, method = "GET", headers = nil, body = nil)
      sleep(self.options.sleep_time) if self.options.sleep_time > 0

      logger.debug { "#{method}: #{uri}" }

      using_connection do |client|
        resp = client.exec(method, path: uri.to_s, headers: headers, body: body)
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
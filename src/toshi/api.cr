require "./options"
require "./api/*"

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

  # Defines the default options for the API
  #
  # ```
  # class MyApi
  #   include Toshi::Api
  #   define_api("api.example.com", "https", 443, "/v1", OpenSSL::SSL::VerifyMode::PEER, HTTP::Headers{
  #     "Content-Type" => "application/json",
  #     "Accept"       => "application/json",
  #   }, 200, 20, 0.1, 0.0)
  # end
  # ```
  #
  # At a minimum, you must provide the host. The rest of the options are optional.
  #
  # ```
  # class MyApi
  #   include Toshi::Api
  #   define_api "api.example.com"
  # end
  # ```
  #
  # The default options are:
  # - `scheme`: `https`
  # - `port`: `443`
  # - `prefix`: `nil`
  # - `tls_verify_mode`: `OpenSSL::SSL::VerifyMode::PEER`
  # - `default_headers`: `HTTP::Headers{ "Content-Type" => "application/json", "Accept" => "application/json" }`
  # - `sleep_time`: `0.0` - the time to sleep between requests
  #
  # The client pool options are:
  # - `pool_capacity`: `200` - the maximum number of clients to create
  # - `initial_pool_size`: `20` - the initial number of clients to create
  # - `pool_timeout`: `0.1` - the timeout to wait for a client to be available
  #
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

  # Defines a new API method based on the given path and method. The method name is derived from the path and method.
  # If the path includes a variable (e.g. `/users/:id`, `/users/:id/books/:book_id`), then the method will be defined with
  # the variables as the first arguments.
  #
  # ```
  # class MyApi
  #   include Toshi::Api
  #   define_api("api.example.com")
  #
  #   define_api_method :get, "/users/:id", User
  #   define_api_method :get, "/users/:id/books/:book_id", UserBook
  # end
  #
  # MyApi.get_users(id: 1)                   # => GET /users/1
  # MyApi.get_users_books(id: 1, book_id: 2) # => GET /users/1/books/2
  # ```
  #
  # You can also define the name of the generated method by passing it:
  #
  # ```
  # class MyApi
  #   include Toshi::Api
  #   define_api("api.example.com")
  #
  #   define_api_method :get, "/users/:id", User, :user_method
  # end
  #
  # MyApi.user_method(id: 1) # => GET /users/1
  # ```
  #
  # If no response class is given, then the response will be `nil`.
  macro define_api_method(method, path, resp_klass = nil, name = nil)
    {% if name == nil
         path_name = path.split("/").map do |part|
           part.starts_with?(":") ? "" : part.gsub(/[\/\-]/, "_")
         end.reject(&.empty?).join("_")
         name = "#{method.id}_#{path_name.id}".gsub(/_{2,}/, "_")
       end %}

    {% if method == :get %}
      define_var_method({{name}}, {{path}}, "GET", {{resp_klass}})
    {% elsif method == :post %}
      define_body_method({{name}}, {{path}}, "POST", {{resp_klass}})
    {% elsif method == :put %}
      define_body_method({{name}}, {{path}}, "PUT", {{resp_klass}})
    {% elsif method == :patch %}
      define_body_method({{name}}, {{path}}, "PATCH", {{resp_klass}})
    {% elsif method == :delete %}
      define_var_method({{name}}, {{path}}, "DELETE", {{resp_klass}})
    {% else %}
      raise "Unknown method: {{method}}"
    {% end %}

    def {{name.id}}(**args)
      {{@type.id}}.{{name.id}}(**args)
    end
  end

  private macro _resp_to_json(resp_klass, resp)
    {% if resp_klass == nil %}
      nil
    {% else %}
      {{resp_klass}}.from_json({{resp}})
    {% end %}
  end

  private macro define_body_method(name, path, method, resp_klass = nil)
    {%
      values = path.split("/").map_with_index do |part, i|
        part.starts_with?(":") ? part.gsub(/^\:/, "") : nil
      end.reject(&.nil?)
    %}

    {% if values.size > 0 %}
    def self.{{name.id}}({{*values.map(&.id)}}, body, params = nil, headers = nil)
      path = {{path}}
      {% for val in values %}
      path = path.gsub(":{{val.id}}", {{val.id}})
      {% end %}
      _resp_to_json({{resp_klass}}, self._request(path, {{method}}, params, headers, body: body))
    end
    {% else %}
    def self.{{name.id}}(body, params = nil, headers = nil)
      _resp_to_json({{resp_klass}}, self._request({{path}}, {{method}}, params, headers, body: body))
    end
    {% end %}
  end

  private macro define_var_method(name, path, method, resp_klass = nil)
    {%
      values = path.split("/").map_with_index do |part, i|
        part.starts_with?(":") ? part.gsub(/^\:/, "") : nil
      end.reject(&.nil?)
    %}

    {% if values.size > 0 %}
    def self.{{name.id}}({{*values.map(&.id)}}, params = nil, headers = nil)
      path = {{path}}
      {% for val in values %}
      path = path.gsub(":{{val.id}}", {{val.id}})
      {% end %}
      _resp_to_json({{resp_klass}}, self._request(path, {{method}}, params, headers))
    end
    {% else %}
    def self.{{name.id}}(params = nil, headers = nil)
      _resp_to_json({{resp_klass}}, self._request({{path}}, {{method}}, params, headers))
    end
    {% end %}
  end
end

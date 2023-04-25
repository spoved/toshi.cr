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

  macro define_api_method(method, path, resp_klass = nil, name = nil)
    {% if name == nil
         name = "#{method.id}_#{path.id.gsub(/[\/\-]/, "_")}".gsub(/_\:.*/, "").gsub(/_{2}/, "_")
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

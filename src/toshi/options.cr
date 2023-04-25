module Toshi::Api
  class Options
    property host : String = "localhost"
    property scheme : String = "https"
    property port : Int32? = nil
    property prefix : String? = nil
    property tls_verify_mode : OpenSSL::SSL::VerifyMode = OpenSSL::SSL::VerifyMode::PEER
    property default_headers : HTTP::Headers = HTTP::Headers{
      "Content-Type" => "application/json; charset=utf-8",
      "Accept"       => "application/json",
    }
    property pool_capacity = 200
    property initial_pool_size = 20
    property pool_timeout = 0.1
    property sleep_time = 0.0

    def initialize(@host, @scheme, @port, @prefix, @tls_verify_mode, @default_headers, @pool_capacity, @initial_pool_size, @pool_timeout, @sleep_time)
    end
  end
end

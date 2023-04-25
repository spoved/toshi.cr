require "json"
require "db/pool"
require "http/client"

module Toshi
  class Error < Exception
    getter code : Int32
    getter resp : String? = nil

    def initialize(@resp : String?, @code : Int32); end

    class ConnectionLost < ::DB::PoolResourceLost(HTTP::Client); end

    class NotFound < Error; end
  end
end

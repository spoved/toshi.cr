module Toshi
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end

require "./toshi/*"

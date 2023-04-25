require "../src/toshi"
require "./spec_client"
require "spectator"

# Spectator.configure do |config|
#   config.before_suite do
#     ::Log.builder.bind(
#       # source: "spec.client",
#       source: "*",
#       level: ::Log::Severity::Trace,
#       backend: ::Log::IOBackend.new(STDOUT, dispatcher: :sync),
#     )
#   end
# end

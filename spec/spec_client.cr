class Spec::Client
  include Toshi::Api

  define_api "reqres.in", prefix: "/api"
end

module Spec::Client
  include Toshi::Api

  define_api "reqres.in", prefix: "/api"

  define_api_method :get_user, "/users/:id", User, :get

  struct User
    include JSON::Serializable
    property data : Data
    property support : Support

    struct Data
      include JSON::Serializable

      property id : Int32
      property email : String
      property first_name : String
      property last_name : String
      property avatar : String
    end

    struct Support
      include JSON::Serializable
      property url : String
      property text : String
    end
  end
end

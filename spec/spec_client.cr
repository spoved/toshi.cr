module Spec::Client
  include Toshi::Api

  define_api "reqres.in", prefix: "/api"

  define_api_method :get_user, "/users/:id", :get, resp_klass: User
  define_api_method(name: :create_user, path: "users", method: :post, resp_klass: Resp::Post)
  define_api_method(:update_user, "users/:id", :put, Resp::Put)
  define_api_method(:patch_user, "users/:id", :patch, Resp::Patch)
  define_api_method(:delete_user, "/users/:id", :delete)

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

  module Resp
    struct Post
      include JSON::Serializable

      property name : String
      property job : String
      property id : String
      @[JSON::Field(key: "createdAt")]
      property created_at : String
    end

    struct Put
      include JSON::Serializable

      property name : String
      property job : String
      @[JSON::Field(key: "updatedAt")]
      property updated_at : String
    end

    alias Patch = Put
  end
end

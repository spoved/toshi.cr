# toshi

Toshi is a Crystal shard for building clients for JSON based apis. It includes a connection pooling, request throttling, and
automatic JSON serialization and deserialization.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     toshi:
       github: spoved/toshi.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "toshi"
```

### Defining an API

First include `Toshi::Api` in your class. Then call `define_api` to define the default configuration for the API.

```crystal
class MyApi
  include Toshi::Api
  define_api("api.example.com", "https", 443, "/v1", OpenSSL::SSL::VerifyMode::PEER, HTTP::Headers{
    "Content-Type" => "application/json",
    "Accept"       => "application/json",
  }, 200, 20, 0.1, 0.0)
end
```

At a minimum, you must provide the host. The rest of the options are optional.

```crystal
class MyApi
  include Toshi::Api
  define_api "api.example.com"
end
```

The default options are:

- `scheme`: `https`
- `port`: `443`
- `prefix`: `nil`
- `tls_verify_mode`: `OpenSSL::SSL::VerifyMode::PEER`
- `default_headers`: `HTTP::Headers{ "Content-Type" => "application/json", "Accept" => "application/json" }`
- `sleep_time`: `0.0` - the time to sleep between requests

The client pool options are:

- `pool_capacity`: `200` - the maximum number of clients to create
- `initial_pool_size`: `20` - the initial number of clients to create
- `pool_timeout`: `0.1` - the timeout to wait for a client to be available

### Defining an API method

`define_api_method` defines a new API method based on the given path and method. The method name is derived from the path and method.
If the path includes a variable (e.g. `/users/:id`, `/users/:id/books/:book_id`), then the method will be defined with
the variables as the first arguments.

```crystal
class MyApi
  include Toshi::Api
  define_api("api.example.com")

  define_api_method :get, "/users/:id", User
  define_api_method :get, "/users/:id/books/:book_id", UserBook
end

MyApi.get_users(id: 1)                   # => GET /users/1
MyApi.get_users_books(id: 1, book_id: 2) # => GET /users/1/books/2
```

You can also define the name of the generated method by passing it:

```crystal
class MyApi
  include Toshi::Api
  define_api("api.example.com")

  define_api_method :get, "/users/:id", User, :user_method
end

MyApi.user_method(id: 1) # => GET /users/1
```

If no response class is given, then the response will be `nil`.

## Contributing

1. Fork it (<https://github.com/spoved/toshi.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Holden Omans](https://github.com/kalinon) - creator and maintainer

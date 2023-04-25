require "../spec_helper"

Spectator.describe Toshi::Api do
  before_each { Spec::Client.configure(nil) }
  let(client) { Spec::Client }

  it "should create default options" do
    expect(client.options.host).to eq "reqres.in"
    expect(client.options.port).to be_nil
    expect(client.options.prefix).to eq "/api"
    expect(client.options.default_headers).to eq(HTTP::Headers{
      "Content-Type" => "application/json",
      "Accept"       => "application/json",
    })
  end

  it "#configure" do
    client.configure do |config|
      config.host = "localhost"
      config.port = 3000
      config.prefix = "/api/v1"
      config.default_headers = HTTP::Headers{
        "Content-Type" => "application/json",
        "Accept"       => "application/json",
      }
    end

    expect(client.options.host).to eq "localhost"
    expect(client.options.port).to eq 3000
    expect(client.options.prefix).to eq "/api/v1"
  end

  context "#make_request" do
    it "200" do
      data = Spec::Client.make_request("/users/2")
      expect(data).to be_a String
      expect(data).to contain("janet.weaver")
    end

    it "404" do
      expect_raises(Toshi::Error::NotFound) do
        Spec::Client.make_request("/unknown/23")
      end
    end
  end
end

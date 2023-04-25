require "../spec_helper"

Spectator.describe Toshi::Api do
  before_each { Spec::Client.configure }
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

  context "#_request" do
    it "200" do
      data = Spec::Client._request("/users/2")
      expect(data).to be_a String
      expect(data).to contain("janet.weaver")
    end

    it "404" do
      expect_raises(Toshi::Error::NotFound) do
        Spec::Client._request("/unknown/23")
      end
    end
  end

  context "#define_api_method" do
    context :get do
      it "200" do
        data = Spec::Client.get_user(2)
        expect(data).to be_a Spec::Client::User
        expect(data.data.email).to contain("janet.weaver")
      end

      it "404" do
        expect_raises(Toshi::Error::NotFound) do
          Spec::Client.get_user(23)
        end
      end
    end

    context :post do
      it "201" do
        data = Spec::Client.create_user({name: "morpheus", job: "leader"})
        expect(data).to be_a Spec::Client::Resp::Post
        expect(data.name).to eq("morpheus")
        expect(data.job).to eq("leader")
        expect(data.id).to_not be_nil
      end
    end

    context :put do
      it "200" do
        data = Spec::Client.update_user(id: 2, body: {name: "morpheus", job: "zion resident"})
        expect(data).to be_a Spec::Client::Resp::Put
        expect(data.name).to eq("morpheus")
        expect(data.job).to eq("zion resident")
      end
    end

    context :patch do
      it "200" do
        data = Spec::Client.patch_users(id: 2, body: {name: "morpheus", job: "zion resident"})
        expect(data).to be_a Spec::Client::Resp::Patch
        expect(data.name).to eq("morpheus")
        expect(data.job).to eq("zion resident")
      end
    end

    context :delete do
      it "204" do
        data = Spec::Client.delete_users(id: 2)
        expect(data).to be_nil
      end
    end
  end
end

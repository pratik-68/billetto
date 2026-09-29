require "rails_helper"

RSpec.describe Billetto::Client do
  subject(:client) { described_class.new(keypair: "key:secret", retry_interval: 0, max_retries: 2) }

  let(:events_url) { "https://billetto.dk/api/v3/public/events" }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  def page_body(ids, next_after: nil)
    {
      object: "list",
      data: ids.map { |id| { id: id.to_s, title: "Event #{id}" } },
      has_more: next_after.present?,
      next_url: next_after && "#{events_url}?after=#{next_after}&limit=2"
    }.to_json
  end

  describe ".from_env" do
    it "raises a configuration error when the keypair is missing" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("BILLETTO_API_KEYPAIR").and_return(nil)

      expect { described_class.from_env }.to raise_error(Billetto::Client::ConfigurationError)
    end
  end

  describe "#each_events_page" do
    it "sends the keypair header and yields the events of a page" do
      stub_request(:get, events_url)
        .with(query: { limit: 100 }, headers: { "Api-Keypair" => "key:secret" })
        .to_return(body: json_fixture("billetto/events_page.json").merge("has_more" => false).to_json, headers: json_headers)

      pages = client.each_events_page.to_a

      expect(pages.size).to eq(1)
      expect(pages.first.map { |event| event["object"] }).to all(eq("public_event"))
    end

    it "follows the cursor until there are no more pages" do
      stub_request(:get, events_url).with(query: { limit: 2 })
        .to_return(body: page_body([ 1, 2 ], next_after: 2), headers: json_headers)
      stub_request(:get, events_url).with(query: { after: "2", limit: "2" })
        .to_return(body: page_body([ 3 ]), headers: json_headers)

      ids = client.each_events_page(page_size: 2).flat_map { |page| page.map { |e| e["id"] } }

      expect(ids).to eq(%w[1 2 3])
    end

    it "stops after max_pages" do
      stub_request(:get, events_url).with(query: { limit: 2 })
        .to_return(body: page_body([ 1, 2 ], next_after: 2), headers: json_headers)

      expect(client.each_events_page(page_size: 2, max_pages: 1).to_a.size).to eq(1)
    end

    it "refuses to follow pagination to another host" do
      body = JSON.parse(page_body([ 1 ], next_after: 1)).merge("next_url" => "https://evil.example/steal").to_json
      stub_request(:get, events_url).with(query: { limit: 100 }).to_return(body: body, headers: json_headers)

      expect { client.each_events_page.to_a }.to raise_error(Billetto::Client::InvalidResponseError, /evil.example/)
    end

    it "raises an authentication error on 401" do
      stub_request(:get, events_url).with(query: hash_including({})).to_return(status: 401)

      expect { client.each_events_page.to_a }.to raise_error(Billetto::Client::AuthenticationError)
    end

    it "retries rate-limited requests and succeeds" do
      stub_request(:get, events_url).with(query: hash_including({}))
        .to_return({ status: 429 }, { body: page_body([ 1 ]), headers: json_headers })

      expect(client.each_events_page.to_a.flatten.size).to eq(1)
    end

    it "raises a server error once retries are exhausted" do
      stub = stub_request(:get, events_url).with(query: hash_including({})).to_return(status: 503)

      expect { client.each_events_page.to_a }.to raise_error(Billetto::Client::ServerError)
      expect(stub).to have_been_requested.times(3) # first try + 2 retries
    end

    it "raises a connection error on timeouts" do
      stub_request(:get, events_url).with(query: hash_including({})).to_timeout

      expect { client.each_events_page.to_a }.to raise_error(Billetto::Client::ConnectionError)
    end

    it "raises on malformed JSON" do
      stub_request(:get, events_url).with(query: hash_including({})).to_return(body: "<html>oops</html>")

      expect { client.each_events_page.to_a }.to raise_error(Billetto::Client::InvalidResponseError, /invalid JSON/)
    end

    it "raises when the response has no data list" do
      stub_request(:get, events_url).with(query: hash_including({})).to_return(body: { error: "nope" }.to_json)

      expect { client.each_events_page.to_a }.to raise_error(Billetto::Client::InvalidResponseError, /no 'data' list/)
    end
  end
end

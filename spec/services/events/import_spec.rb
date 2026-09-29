require "rails_helper"

RSpec.describe Events::Import do
  subject(:import) { described_class.new(client: client, logger: Logger.new(nil)) }

  let(:client) { instance_double(Billetto::Client) }
  let(:fixture_events) { json_fixture("billetto/events_page.json").fetch("data") }

  def stub_pages(*pages)
    allow(client).to receive(:each_events_page) { |**, &block| pages.each(&block) }
  end

  def raw_event(id, **overrides)
    fixture_events.first.merge("id" => id.to_s, **overrides.stringify_keys)
  end

  it "creates events from every page" do
    stub_pages(fixture_events, [ raw_event(99) ])

    result = import.call

    expect(result).to have_attributes(fetched: 3, imported: 3, skipped: 0)
    expect(Event.pluck(:external_id)).to match_array(fixture_events.map { |e| e["id"] } + [ "99" ])
  end

  it "is idempotent and updates events that changed upstream" do
    stub_pages([ raw_event(1, title: "Old title") ])
    import.call
    stub_pages([ raw_event(1, title: "New title") ])

    expect { import.call }.not_to change(Event, :count)
    expect(Event.find_by!(external_id: "1").title).to eq("New title")
  end

  it "skips invalid events without aborting the page" do
    stub_pages([ raw_event(1), raw_event(2, title: nil), raw_event(3, startdate: "garbage"), raw_event(4, enddate: "2000-01-01T00:00:00Z") ])

    result = import.call

    expect(result).to have_attributes(fetched: 4, imported: 1, skipped: 3)
    expect(Event.pluck(:external_id)).to eq([ "1" ])
  end

  it "keeps the last occurrence when a page repeats an event" do
    stub_pages([ raw_event(1, title: "First"), raw_event(1, title: "Second") ])

    import.call

    expect(Event.sole.title).to eq("Second")
  end

  it "keeps pages imported before an API error" do
    allow(client).to receive(:each_events_page) do |**, &block|
      block.call([ raw_event(1) ])
      raise Billetto::Client::ServerError, "boom"
    end

    expect { import.call }.to raise_error(Billetto::Client::ServerError)
    expect(Event.pluck(:external_id)).to eq([ "1" ])
  end
end

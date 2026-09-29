require "rails_helper"

RSpec.describe Billetto::EventPayload do
  let(:raw) { json_fixture("billetto/events_page.json").fetch("data").first }

  it "maps a real API event onto Event attributes" do
    attributes = described_class.new(raw).to_event_attributes

    expect(attributes).to include(
      external_id: raw["id"],
      title: raw["title"],
      starts_at: Time.iso8601(raw["startdate"]),
      ends_at: Time.iso8601(raw["enddate"]),
      url: raw["url"],
      image_url: raw["image_link"],
      city: raw.dig("location", "city"),
      raw_payload: raw
    )
  end

  it "strips whitespace and blanks out empty strings" do
    attributes = described_class.new(raw.merge("title" => "  Jazz night \n", "description" => "   ")).to_event_attributes

    expect(attributes).to include(title: "Jazz night", description: nil)
  end

  it "returns nil for unparseable or missing dates" do
    attributes = described_class.new(raw.merge("startdate" => "next tuesday", "enddate" => nil)).to_event_attributes

    expect(attributes).to include(starts_at: nil, ends_at: nil)
  end

  it "tolerates payloads with an unexpected shape" do
    expect(described_class.new("not a hash").to_event_attributes).to include(external_id: nil, title: nil)
    expect(described_class.new(raw.merge("location" => "Copenhagen")).to_event_attributes).to include(city: nil)
  end
end

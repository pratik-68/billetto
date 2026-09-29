require "rails_helper"

RSpec.describe Event do
  subject(:event) { build(:event) }

  it "is valid with the factory defaults" do
    expect(event).to be_valid
  end

  %i[external_id title starts_at synced_at].each do |attribute|
    it "requires #{attribute}" do
      event.public_send("#{attribute}=", nil)

      expect(event).not_to be_valid
      expect(event.errors[attribute]).to include("can't be blank")
    end
  end

  it "limits the title length" do
    event.title = "a" * 256

    expect(event).not_to be_valid
  end

  it "rejects an end time before the start time" do
    event.ends_at = event.starts_at - 1.minute

    expect(event).not_to be_valid
    expect(event.errors[:ends_at]).to include("must be on or after the start time")
  end

  it "allows a missing end time" do
    event.ends_at = nil

    expect(event).to be_valid
  end

  it "rejects non-http urls" do
    event.url = "javascript:alert(1)"
    event.image_url = "not a url"

    expect(event).not_to be_valid
    expect(event.errors.attribute_names).to include(:url, :image_url)
  end

  describe "database constraints" do
    it "enforces unique external_id even when validations are skipped" do
      create(:event, external_id: "7")

      expect { build(:event, external_id: "7").save(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces ends_at >= starts_at even when validations are skipped" do
      invalid = build(:event, ends_at: 1.day.ago, starts_at: Time.current)

      expect { invalid.save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /events_ends_after_start/)
    end
  end

  describe ".upcoming" do
    it "returns unfinished events ordered by start time" do
      later = create(:event, starts_at: 2.days.from_now)
      sooner = create(:event, starts_at: 1.day.from_now)
      in_progress = create(:event, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
      create(:event, starts_at: 2.days.ago, ends_at: 1.day.ago)

      expect(described_class.upcoming).to eq([ in_progress, sooner, later ])
    end
  end
end

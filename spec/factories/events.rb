FactoryBot.define do
  factory :event do
    sequence(:external_id) { |n| (1_000_000 + n).to_s }
    title { "Saunagus i Badeklubben" }
    description { "An evening of sauna rituals." }
    starts_at { 3.days.from_now.change(usec: 0) }
    ends_at { starts_at + 3.hours }
    url { "https://billetto.dk/e/saunagus-#{external_id}" }
    image_url { "https://billetto.imgix.net/image-#{external_id}.jpg" }
    synced_at { Time.current }
  end
end

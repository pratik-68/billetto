# A public event ingested from the Billetto API. Billetto is the source of truth;
# rows are upserted by `external_id` (see Events::Import).
class Event < ApplicationRecord
  has_one :vote_tally, dependent: :delete
  has_many :event_votes, dependent: :delete_all

  # Uniqueness of external_id is enforced by a unique index: imports upsert on it,
  # which a per-record uniqueness validation could neither see nor make race-free.
  validates :external_id, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :starts_at, :synced_at, presence: true
  validate :ends_at_not_before_starts_at
  validate :urls_are_http

  # Events that have not finished yet, soonest first.
  scope :upcoming, ->(now = Time.current) {
    where("COALESCE(events.ends_at, events.starts_at) >= ?", now).order(:starts_at, :id)
  }

  private

  def ends_at_not_before_starts_at
    return if ends_at.blank? || starts_at.blank?

    errors.add(:ends_at, "must be on or after the start time") if ends_at < starts_at
  end

  def urls_are_http
    %i[url image_url].each do |attribute|
      value = public_send(attribute)
      next if value.blank? || http_url?(value)

      errors.add(attribute, "must be a valid http(s) URL")
    end
  end

  def http_url?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end

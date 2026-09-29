require "rails_helper"

RSpec.describe "Events" do
  it "lists upcoming events with title, date, image, description and vote counts" do
    event = create(:event, title: "Copenhagen Jazz", description: "<b>Live</b> music " + "la " * 200)
    create(:event, title: "Last year's party", starts_at: 1.year.ago, ends_at: 1.year.ago + 2.hours)
    command_bus.call(Voting::UpvoteEvent.new(event_id: event.id, user_id: "user_1"))

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Copenhagen Jazz", event.image_url, event.starts_at.iso8601, "#{I18n.l(event.starts_at, format: :long)} UTC")
    expect(response.body).not_to include("Last year's party", "<b>Live</b>")
    expect(response.body).to include('<span data-upvotes>1</span>')
  end

  it "paginates" do
    create_list(:event, EventsController::PER_PAGE + 1)

    get root_path
    expect(response.body).to include("Next →")

    get root_path(page: 2)
    expect(response.body.scan('class="event"').size).to eq(1)
  end
end

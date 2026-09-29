require "rails_helper"

# End-to-end authentication against a real Clerk development instance.
# Opt-in: CLERK_E2E=1 bundle exec rspec --tag clerk
#
# Uses Clerk test mode: emails containing "+clerk_test" receive no real email and
# accept the verification code 424242.
RSpec.describe "Clerk authentication", :clerk do
  let!(:event) { create(:event, title: "Harbour concert", image_url: nil) }
  let(:email) { "billetto+clerk_test_#{SecureRandom.hex(4)}@example.com" }
  let(:password) { "Billetto-e2e-#{SecureRandom.hex(8)}" }

  around do |example|
    previous_wait, Capybara.default_max_wait_time = Capybara.default_max_wait_time, 20 # Clerk round trips
    example.run
  ensure
    Capybara.default_max_wait_time = previous_wait
  end

  before { use_clerk_testing_token } # bypass bot protection (spec/support/clerk_testing_token.rb)

  def enter_verification_code_if_asked
    return unless page.has_text?(/verif|code/i, wait: 5)

    code_field = first("input[autocomplete='one-time-code'], input[name='code']", minimum: 0, visible: :all)
    if code_field
      code_field.click
      code_field.send_keys("424242")
    else
      first("input[inputmode='numeric']").click
      page.driver.browser.keyboard.type("424242")
    end
  end

  def fill_and_continue(name, value)
    find("input[name='#{name}']").fill_in(with: value)
    find(".cl-formButtonPrimary").click # Clerk's stable class for the primary form button
  end

  it "signs up, votes, signs out and signs back in" do
    # Sign up
    visit sign_up_path
    find("input[name='emailAddress']").fill_in(with: email)
    fill_and_continue("password", password)
    enter_verification_code_if_asked

    expect(page).to have_button("Sign out")
    expect(page).to have_current_path(root_path)

    # Vote as the Clerk user
    within("#event_#{event.id}") { click_button "Upvote" }
    within("#event_#{event.id}") { expect(find("[data-upvotes]")).to have_text("1") }

    upvote = event_store.read.of_type(Voting::EventUpvoted).last
    expect(upvote.data[:user_id]).to start_with("user_")
    expect(upvote.metadata[:user_id]).to eq(upvote.data[:user_id])

    # Sign out
    click_button "Sign out"
    expect(page).to have_link("Sign in")
    within("#event_#{event.id}") { expect(page).to have_link("Sign in to vote") }

    # Sign in again
    visit sign_in_path
    fill_and_continue("identifier", email)
    fill_and_continue("password", password)
    enter_verification_code_if_asked

    expect(page).to have_button("Sign out")
    within("#event_#{event.id}") { expect(page).to have_button("Upvote", disabled: true) }
  end
end

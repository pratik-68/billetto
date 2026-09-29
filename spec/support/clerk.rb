# Signed-in state for specs without talking to Clerk.
#
# Clerk::Rack::Middleware is skipped in tests (see rails_helper). FakeClerkSession takes
# its place and builds the same `request.env["clerk"]` proxy the real middleware builds
# from a verified session token, taking the user id from a test-only cookie.
class FakeClerkSession
  COOKIE = "test_clerk_user_id".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    user_id = Rack::Request.new(env).cookies[COOKIE].presence
    env["clerk"] = Clerk::Proxy.new(session_claims: user_id && { "sub" => user_id })
    @app.call(env)
  end
end

module ClerkHelpers
  # Request specs
  def sign_in_as(user_id)
    cookies[FakeClerkSession::COOKIE] = user_id
  end

  # System specs (Cuprite); call after the first visit so the cookie has a domain.
  def browser_sign_in_as(user_id)
    page.driver.set_cookie(FakeClerkSession::COOKIE, user_id)
  end
end

RSpec.configure do |config|
  config.include ClerkHelpers, type: :request
  config.include ClerkHelpers, type: :system
end

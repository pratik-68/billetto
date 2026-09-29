# Block real HTTP in tests; Capybara/Cuprite need localhost for browser specs.
# The opt-in Clerk end-to-end specs (CLERK_E2E=1) verify real session tokens, which
# needs Clerk's Backend and Frontend APIs.
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: ENV["CLERK_E2E"] ? [ "api.clerk.com", /\.clerk\.accounts\.dev\z/ ] : []
)

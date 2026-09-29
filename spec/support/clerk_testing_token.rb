# Clerk bot protection blocks automated browsers from signing up. For end-to-end specs
# Clerk issues short-lived Testing Tokens (Backend API) which, sent as the
# `__clerk_testing_token` query param on Frontend API requests, bypass it. This is what
# @clerk/testing does for Playwright/Cypress; here Ferrum's request interception does it.
module ClerkTestingToken
  PARAM = "__clerk_testing_token".freeze

  def use_clerk_testing_token
    token = Clerk::SDK.new(secret_key: ENV.fetch("CLERK_SECRET_KEY")).testing_tokens.create.testing_token.token
    frontend_api = Base64.decode64(ENV.fetch("CLERK_PUBLISHABLE_KEY").split("_", 3).last).delete_suffix("$")

    browser = page.driver.browser
    browser.network.intercept
    browser.on(:request) do |request|
      uri = URI(request.url)
      if uri.host == frontend_api && uri.path.start_with?("/v1/")
        uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s) << [ PARAM, token ])
        request.continue(url: uri.to_s)
      else
        request.continue
      end
    end
  end
end

RSpec.configure do |config|
  config.include ClerkTestingToken, :clerk
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"

# Specs use a fake Clerk session (spec/support/clerk.rb) and never call Clerk, unless
# CLERK_E2E=1 is set to run the real sign-up / sign-in flow (`CLERK_E2E=1 bundle exec rspec --tag clerk`).
require_relative "../config/application"
unless ENV["CLERK_E2E"]
  ENV["CLERK_SKIP_RAILTIE"] = "true"
  ENV["CLERK_PUBLISHABLE_KEY"] = ""
  require_relative "support/clerk"
  Rails.application.config.middleware.use FakeClerkSession
end
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.filter_run_excluding :clerk unless ENV["CLERK_E2E"]
end

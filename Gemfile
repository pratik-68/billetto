source "https://rubygems.org"

# Only the Rails frameworks this app uses (no mailer, cable, storage, text, mailbox).
RAILS_VERSION = "~> 8.1.3"
gem "railties", RAILS_VERSION
gem "activerecord", RAILS_VERSION
gem "actionpack", RAILS_VERSION
gem "actionview", RAILS_VERSION
gem "activejob", RAILS_VERSION

gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Event store for the voting feature [https://railseventstore.org] (includes aggregate_root)
gem "rails_event_store", "~> 3.0.1" # 3.1+ requires Ruby 3.3

# HTTP client for the Billetto API
gem "faraday", "~> 2.12"
gem "faraday-retry", "~> 2.2"

# Clerk.com authentication (session token verification)
gem "clerk-sdk-ruby", "~> 8.0", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "dotenv-rails"
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
end

group :test do
  gem "ruby_event_store-rspec", "~> 3.0.1"
  gem "webmock"
  gem "capybara"
  gem "cuprite"
end

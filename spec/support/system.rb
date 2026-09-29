require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1200, 900 ], headless: ENV["HEADLESS"] != "false", process_timeout: 20, timeout: 15)
end
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :cuprite }
end

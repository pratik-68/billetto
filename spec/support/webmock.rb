# Block real HTTP in tests; Capybara/Cuprite need localhost for browser specs.
WebMock.disable_net_connect!(allow_localhost: true)

module FixtureFileHelpers
  def json_fixture(path)
    JSON.parse(Rails.root.join("spec/fixtures", path).read)
  end
end

RSpec.configure { |config| config.include FixtureFileHelpers }

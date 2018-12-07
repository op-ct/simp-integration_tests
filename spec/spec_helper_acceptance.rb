require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'

$LOAD_PATH.unshift(File.expand_path("#{__dir__}/acceptance/support/lib"))
require 'simp/integration_test/helpers'

# rubocop:disable Style/MixinUsage
include Simp::BeakerHelpers
# rubocop:enable Style/MixinUsage

# NOTE: The `install_puppet` method is intentionally omitted in these helpers;
#       SUTs prepared for SIMP integration tests alredy have Puppet installed.

RSpec.configure do |c|
  # provide helpers to individual examples AND example groups
  c.include Simp::IntegrationTest::Helpers
  c.extend  Simp::IntegrationTest::Helpers

  # Readable test descriptions
  c.formatter = :documentation
end

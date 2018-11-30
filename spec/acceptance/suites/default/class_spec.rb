require 'spec_helper_acceptance'

test_name 'integration_tests class'

describe 'integration_tests class' do
  let(:manifest) do
    <<-MANIFEST
      file{ '/root/.beaker-suites.smoke_test.file':
        content => 'Beaker wrote this file!'
      }
    MANIFEST
  end

  context 'when there no parameters are changed' do
    it 'works with no errors' do
require 'pry'; binding.pry
      apply_manifest(manifest, :catch_failures => true)
    end

    it 'is idempotent' do
      apply_manifest(manifest, :catch_changes => true)
    end

    it 'creates the smoke test file' do
      puppetserver = find_at_most_one_host_with_role hosts, 'master'
      on puppetserver, 'grep Beaker /root/.beaker-suites.smoke_test.file'
    end
  end
end

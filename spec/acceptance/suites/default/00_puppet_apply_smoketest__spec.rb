require 'spec_helper_acceptance'

test_name 'puppet apply smoke test'

# This smoke test establishes that the local puppet installation works before
# attempting
describe 'local puppet commands work (smoke tests)' do
  let(:manifest) do
    <<-MANIFEST
      file{ '/root/.beaker-suites.smoke_test.file':
        content => 'Beaker wrote this file!'
      }
    MANIFEST
  end

  context 'when running `puppet apply`' do
    it 'works with no errors' do
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

  context 'when running `puppet describe`' do
    it 'works with no errors' do
      on puppetserver, 'puppet describe cron'
    end
  end
end

require 'spec_helper_acceptance'
require 'simp/integration_test/upgrade_helpers'
require 'simp/integration_test/errata_helpers'

# The `upgrade` suite validates the SIMP user guide's General Upgrade
# Instructions for incremental upgrades.
#
# It automates the Verify SIMP server RPM upgrade pre-release checklist.
#
# Example:
#
#   BEAKER_vagrant_box_tree=$vagrant_boxes_dir \
#   BEAKER_box__puppet="simpci/SIMP-6.1.0-0-Powered-by-CentOS-7.0-x86_64" \
#   BEAKER_upgrade__new_simp_iso_path=$PWD\SIMP-6.2.0-RC1.el7-CentOS-7.0-x86_64.iso \
#   bundle exec rake beaker:suites[upgrade]
#
# Requirements:
#
# - The SUT (`BEAKER_box__puppet`) is a PREVIOUS version of SIMP.
# - The ISO (`BEAKER_upgrade__new_simp_iso_path`) is the current version of SIMP.
#
# Optional:
#
# - Any *.rpm files you want to inject into the yum repo prior to `unpack_dvd`

test_name 'General Upgrade: incremental upgrades'

describe 'when an older version of SIMP' do
  RSpec.configure do |c|
    # provide helpers to individual examples AND example groups
    c.include Simp::IntegrationTest::UpgradeHelpers
    c.extend  Simp::IntegrationTest::UpgradeHelpers
    c.include Simp::IntegrationTest::ErrataHelpers
    c.extend  Simp::IntegrationTest::ErrataHelpers
  end

  before(:all) do
    # record original simp version before upgrade
    original_simp_version
    @hopefully_temporary_gpg_hack = ENV.fetch('HOPEFULLY_TEMPORARY_GPG_HACK', 'yes') == 'yes'
  end

  let(:puppet_agent_t) do
    'set -o pipefail; puppet agent -t --detailed-exitcodes'
  end

  let(:module_path) do
    on(
      puppetserver,
      'puppet config print modulepath --section master'
    ).stdout.split(':').first
  end

  let(:iso_files) do
    host_os_version = on(
      puppetserver,
      'echo "$(facter os.name)-$(facter os.release.major)"'
    ).stdout.strip
    local_iso_files_matching "*#{host_os_version}*.iso"
  end

  context 'when upgrading incrementally' do
    before :all do
      # (TODO: Remove this after SIMP-5385?)
      on puppetserver, 'puppet resource cron puppetagent ensure=absent'
    end

    it 'uploads the ISO file(s)' do
      expect(iso_files).not_to be_empty
      on puppetserver, 'mkdir -p /var/isos'
      iso_files.each do |file|
        puppetserver.do_rsync_to file, "/var/isos/#{File.basename(file)}"
      end
    end

    it 'runs the unpack_dvd script' do
      upload_rpms_to_yum_repo # inject rpms
      iso_files.each do |file|
        on puppetserver, "unpack_dvd /var/isos/#{File.basename(file)}"
      end
      on puppetserver, 'yum clean all; yum makecache'
    end

    it 'runs `yum update`' do
      simp_errata(:before_yum_upgrade)

      # r = on puppetserver, 'yum --rpmverbosity=warn -y update || ' \
      r = on puppetserver, 'yum -y update || ' \
        '{ printf "\n\n\n==== step failed - check for GPG problems ' \
           '\n\nCheck the errors above for missing GPG keys--if found:\n' \
           'Try running this beaker again" ; }',
             accept_all_exit_codes: true

      if r.exit_code != 0
        puts '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
        puts '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
        puts '%%%%%%          previous yum update -y failed!         %%%%%%%'
        puts '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
        puts '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
        require 'pry'; binding.pry
        on puppetserver, 'yum --rpmverbosity=warn -y update || ' \
        '{ printf "\n\n\n==== step failed (again) - check for GPG problems ' \
           '\n\nCheck the errors above for missing GPG keys or other problems' \
      end
    end

    it 'runs `puppet agent -t` to apply changes' do
      archive_file_from(puppetserver, '/var/log/puppetlabs/puppetserver/puppetserver-daemon.log')
      archive_file_from(puppetserver, '/var/log/puppetserver.log')
      # SIMP 6.2->6.3 upgrade: puppet server is dead.  Why?
      require 'pry'; binding.pry
      agent_run_cmd = "#{puppet_agent_t} " \
                      '|& tee /root/puppet-agent.log.01.yum-update'
      on puppetserver, agent_run_cmd, :acceptable_exit_codes => [2]

      # if errata needed to be applied after the upgrade, run the agent an
      # extra time to make sure everything upgraded cleanly before the next
      # tests
      if simp_errata(:after_yum_upgrade)
        agent_run_cmd = "#{puppet_agent_t} " \
                        '|& tee /root/puppet-agent.log.02.yum-update-post-errata'
        on puppetserver, agent_run_cmd, :acceptable_exit_codes => [2]
      end
    end

    it 'runs `puppet agent -t` idempotently' do
      agent_run_cmd = "#{puppet_agent_t} " \
                      '|& tee /root/puppet-agent.log.10.runs-idempotently'
      on puppetserver, agent_run_cmd, :acceptable_exit_codes => [0]
    end

    after :all do
      opts = { silent: true }
      archive_root = 'archive/suites/upgrade/sut-files'
      archive_file_from(puppetserver, '/var/log/puppetlabs/puppetserver/puppetserver-daemon.log')
      archive_file_from(puppetserver, '/var/log/puppetserver.log')
      agent_logs = on(puppetserver, 'ls -1 /root/puppet-agent.log.*', silent: true).stdout.strip.split("\n")
      agent_logs.each { |log| archive_file_from(puppetserver, log) }
    end
  end
end

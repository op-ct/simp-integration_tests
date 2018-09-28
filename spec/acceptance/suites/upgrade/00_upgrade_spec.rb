require 'spec_helper_acceptance'

# The `upgrade` suite validates the SIMP user guide's [General Upgrade
# Instructions for incremental upgrades][u0].
#
# It automates the [Verify SIMP server RPM upgrade pre-release checklist][u1].
#
# Example:
#
#   BEAKER_vagrant_box_tree=$vagrant_boxes_dir \
#   BEAKER_box__puppet="simpci/SIMP-6.1.0-0-Powered-by-CentOS-7.0-x86_64" \
#   BEAKER_upgrade__new_simp_iso_path=$PWD\SIMP-6.2.0-RC1.el6-CentOS-6.9-x86_64.iso \
#   bundle exec rake beaker:suites[upgrade]
#
# Requirements:
#
# - The SUT (`BEAKER_box__puppet`) is a PREVIOUS version of SIMP.
# - The ISO (`BEAKER_upgrade__new_simp_iso_path`) is the current version of SIMP.
#
# [u0]: https://github.com/simp/simp-doc/blob/8277eab/docs/user_guide/Upgrade_SIMP/General_Upgrade_Instructions.rst#incremental-updates
# [u1]: https://github.com/simp/simp-doc/blob/aebb9f7/docs/contributors_guide/maintenance/iso_release_procedures/Pre_Release_Checklist.rst#verify-simp-server-rpm-upgrade

test_name 'General Upgrade: incremental upgrades'

describe 'when an older version of SIMP' do
  PUPPET_SERVER = find_at_most_one_host_with_role hosts, 'master'
  ORIGINAL_SIMP_VERSION = on(
    PUPPET_SERVER,
    'cat /etc/simp/simp.version',
    silent: true
  ).stdout.strip

  let(:puppetserver) { PUPPET_SERVER }

  let(:original_simp_version) { ORIGINAL_SIMP_VERSION }

  let(:puppet_agent_t) do
    'set -o pipefail; puppet agent -t --detailed-exitcodes' \
      ' |& tee /root/puppet-agent.log'
  end

  let(:module_path) do
    on(
      PUPPET_SERVER,
      'puppet config print modulepath --section master'
    ).stdout.split(':').first
  end

  let(:iso_files) do
    host_os_version = on(
      PUPPET_SERVER,
      'echo "$(facter os.name)-$(facter os.release.major)"'
    ).stdout.strip
    local_iso_files_matching "*#{host_os_version}*.iso"
  end

  context 'when upgrading incrementally' do
    before :all do
      # (TODO: Remove this after SIMP-5385)
      on PUPPET_SERVER, 'puppet resource cron puppetagent ensure=absent'
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
      errata_for_simp5383__yum_excludes(:add)
      on puppetserver, 'yum --rpmverbosity=warn -y update'
    end

    it 'runs `puppet agent -t` to apply changes' do
      on puppetserver, "#{puppet_agent_t}.1", :acceptable_exit_codes => [2]

      if errata_for_simp5383__yum_excludes(:remove)
        # SIMP-5383: run agent an extra time to upgrade the agent
        on puppetserver, "#{puppet_agent_t}.2", :acceptable_exit_codes => [2]
      end
    end

    it 'runs `puppet agent -t` idempotently' do
      on puppetserver, "#{puppet_agent_t}.3", :acceptable_exit_codes => [0]
    end

    # Helper methods
    # --------------------------------------------------------------------------

    # based on the env var `BEAKER_upgrade__new_simp_iso_path` or a file glob,
    # returns an Array of isos if found, or fails if not
    def local_iso_files_matching(default_file_glob)
      isos = if (iso_files = ENV['BEAKER_upgrade__new_simp_iso_path'])
               iso_files.to_s.split(%r{[:,]})
             else
               Dir[default_file_glob]
             end
      return isos unless isos.empty?
      raise <<-NO_ISO_FILE_ERROR.gsub(%r{^ {6}}, '')

        --------------------------------------------------------------------------------
        ERROR: No SIMP ISO(s) to upload for upgrade!
        --------------------------------------------------------------------------------

        This test requires at least one newer SIMP .iso

        You can provide .iso files either by setting the environment variable:

            BEAKER_upgrade__new_simp_iso_path=/path/to/iso-file.iso

        Or:

        Place a file that matches the glob '#{default_file_glob}'
        into the top directory of this project.

        --------------------------------------------------------------------------------

      NO_ISO_FILE_ERROR
    end

    # Upload matching local RPMs into the puppetserver's yum repo
    def upload_rpms_to_yum_repo(base_dir = '.', rpm_globs = ['*.noarch.rpm'])
      expanded_globs = rpm_globs.map { |glob| File.join(base_dir, glob) }
      local_rpms = Dir[*expanded_globs]
      return if local_rpms.empty?
      yum_dir = '/var/www/yum/SIMP/x86_64/'
      local_rpms.each do |local_rpm|
        scp_to(puppetserver, local_rpm, yum_dir)
        on(
          puppetserver,
          "chmod 0644 #{yum_dir}/#{File.basename(local_rpm)}; " \
          "chown root:apache #{yum_dir}/#{File.basename(local_rpm)}"
        )
      end
    end

    # Errata methods
    # --------------------------------------------------------------------------
    # - errata_* methods execute workarounds or patches for known problems.
    # - doesn't apply  check to see if it applies return nil if
    # --------------------------------------------------------------------------
    # Specific 6.1.0->* upgrade instructions, due to SIMP-5383

    def errata_for_simp5383__yum_excludes(action)
      return unless original_simp_version.start_with?('6.1.')
      warn '== ERRATA (SIMP-5385): Special 6.1.0 -> * upgrade instructions:',
           "==                       * #{action}: exclude=puppet-agent >> yum.conf`"
      cmd = 'puppet resource file_line yum_exclude path=/etc/yum.conf ' \
            "line='exclude=puppet-agent'"
      cmd += ' ensure=absent' if action == :remove
      on puppetserver, cmd
    end
  end
end

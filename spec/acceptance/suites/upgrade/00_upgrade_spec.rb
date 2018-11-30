require 'spec_helper_acceptance'

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

module Simp
  module IntegrationTestHelpers
    # @return [String] puppetserver
    def puppetserver
      @puppet_server_host ||= find_at_most_one_host_with_role(hosts, 'master')
    end

    # Return (and remember) the host's SIMP version at the beginning of
    #   the test.
    #
    # @param host [String] the host (puppetserver())
    # @return [String] th host's original version of SIMP
    #
    # @note: Make sure to run this method at the beginning of the suite (before
    #   upgrading) to make sure it locks onto the correct version!
    #
    def original_simp_version(host=puppetserver())
      @original_simp_version ||= {}
      @original_simp_version[host] ||= on(
        host, 'cat /etc/simp/simp.version', silent: true
      ).stdout.strip
    end

    # Queries and returns the SIMP version of the given host.
    #
    # @param host [String] the host (puppetserver())
    # @return [String] the puppetserver's original version of SIMP (when the
    #    suite began)
    def simp_version(host=puppetserver())
      on(host, 'cat /etc/simp/simp.version', silent: true).stdout.strip
    end

    # Queries and returns the latest available SIMP version in yum
    #
    # @param host [String] the host (puppetserver())
    # @return [String] the latest available SIMP version in yum
    def latest_available_simp_version(host=puppetserver)
      cmd = 'yum list simp | grep ^Available -A40 | grep "^simp\>"'
      on(host, cmd , silent: true).stdout.lines.map(&:strip).last.split(/\s+/)[1]
    end

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

    def simp_errata(label, opts={})
      result = nil
      case label
      when :before_yum_upgrade
        #todo: summarize what errata was applied
        result = errata_for_simp5383__yum_excludes(:add)
        result = errata_for_simp_6_2_to_6_3_upgrade__pre_yum
      when :after_yum_upgrade
        result = errata_for_simp5383__yum_excludes(:remove)
      else
         raise "Unrecognized SIMP errata label: '#{label}'"
      end
      result
    end


    # Compare semver, and by default chop off non X.Y.Z suffixes like '-BETA.*'
    def semver_match(expr, version, chop_suffix=true)
      version = version.sub(/[+-].+$/,'') if chop_suffix
      Gem::Dependency.new('', expr).match?('', version)
    end

    # Specific errata helpers
    # --------------------------------------------------------------------------
    # errata_* methods:
    # - execute workarounds or patches for known problems.
    # - must return nil immediately if it doesn't apply
    # --------------------------------------------------------------------------

    # Specific 6.1.0->* upgrade instructions, due to SIMP-5383
    # @param action [:add,:remove] Whether to `:add` or `:remove` the line
    #   `exclude=puppet-agent` from `/etc/yum.conf`
    def errata_for_simp5383__yum_excludes(action)
      return unless original_simp_version.start_with?('6.1.')
      warn '','== ERRATA (SIMP-5385): Special 6.1.0 -> * upgrade instructions:',
           "==                       * #{action}: exclude=puppet-agent >> yum.conf`"
      cmd = 'puppet resource file_line yum_exclude path=/etc/yum.conf ' \
            "line='exclude=puppet-agent'"
      cmd += ' ensure=absent' if action == :remove
      on puppetserver, cmd
    end

    def errata_for_simp_6_2_to_6_3_upgrade__pre_yum
      return unless [
        semver_match('< 6.3',  simp_version),
        semver_match('>= 6.3', latest_available_simp_version)
      ].all?
      warn '','== ERRATA (SIMP-????): Special <6.3 -> >=6.3 upgrade instructions:',
           "==                       * ???????????????????????????????"

      # https://tickets.puppetlabs.com/browse/SERVER-1971
      # (Also see: https://tickets.puppetlabs.com/browse/SERVER-1971?focusedCommentId=492050&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-492050)
      on puppetserver, 'puppet resource file_line filewatch_fix ' \
                       'path=/etc/puppetlabs/puppetserver/services.d/ca.cfg ' \
                       'line=puppetlabs.trapperkeeper.services.watcher.filesystem-watch-service/filesystem-watch-service'

      # SIMP-5340 again?
      hocon='/opt/puppetlabs/puppet/bin/hocon'
      file='/etc/puppetlabs/puppetserver/conf.d/web-routes.conf'
      cfg='web-router-service."puppetlabs.trapperkeeper.services.metrics.metrics-service/metrics-webservice"'
      value='"/metrics"'
      on puppetserver, %Q[#{hocon} -f #{file} set '#{cfg}' '#{value}' ]

    end
  end
end


test_name 'General Upgrade: incremental upgrades'

describe 'when an older version of SIMP' do
  include Simp::IntegrationTestHelpers


  before(:all) do
    # record original simp version before upgrade
    original_simp_version()
    @hopefully_temporary_gpg_hack = ENV.fetch('HOPEFULLY_TEMPORARY_GPG_HACK','yes') == 'yes'
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
      if @hopefully_temporary_gpg_hack
        warn '', '', '='*80
        warn "HOPEFULLY_TEMPORARY_GPG_HACK=yes"
        warn '='*80, '', ''
        # FIXME: troubleshoot why this is happening:
        #   - Is my SIMP 6.2.0 box bad?
        #     - [ ] [in progress] rebuild from SIMP 6.2.0 EL6 ISO release
        #     - [ ] test with freshly-built .box from SIMP 6.2.0 EL6 ISO release
        #   - Does this only affect EL6?
        #     - [ ] rebuild from SIMP 6.2.0 EL7 ISO release
        #     - [ ] test with freshly-built .box from SIMP 6.2.0 EL7 ISO release
        #   - Are dev GPG keys going in the wrong place?
        #     - If so: does this only happen with _dev_ GPG keys?
        require 'pry'; binding.pry
        on puppetserver,
           'cat /var/www/yum/CentOS/6.10/x86_64/RPM-GPG-KEY-SIMP-Dev ' \
           '> /var/www/yum/SIMP-Dev/GPGKEYS/RPM-GPG-KEY-SIMP-Dev'
      else
        warn '', '', '='*80
        warn " the HOPEFULLY_TEMPORARY_GPG_HACK=yes"
        warn '='*80, '', ''
      end

      on puppetserver, 'yum --rpmverbosity=warn -y update || ' \
        '{ printf "\n\n\n==== step failed - check for GPG problems ' \
           '\n\nCheck the errors above for missing GPG keys--if found:\n' \
           'Try running this beaker again env  HOPEFULLY_TEMPORARY_GPG_HACK=yes\n\n====\n\n\n"; exit 99; }'
    end

    it 'runs `puppet agent -t` to apply changes' do
      agent_run_cmd = "#{puppet_agent_t} " + \
         '|& tee /root/puppet-agent.log.01.yum-update'
      on puppetserver, agent_run_cmd, :acceptable_exit_codes => [2]

      # if there was errata for after the upgrade, run the agent an extra time to
      # make sure everything upgraded cleanly before the next tests
      if simp_errata(:after_yum_upgrade)
        agent_run_cmd = "#{puppet_agent_t} " + \
           '|& tee /root/puppet-agent.log.02.yum-update-post-errata'
        on puppetserver, agent_run_cmd, :acceptable_exit_codes => [2]
      end
    end

    it 'runs `puppet agent -t` idempotently' do
      agent_run_cmd = "#{puppet_agent_t} " + \
         '|& tee /root/puppet-agent.log.10.runs-idempotently'
      on puppetserver, agent_run_cmd, :acceptable_exit_codes => [0]
    end

    # Helper methods
    # --------------------------------------------------------------------------


  end
end

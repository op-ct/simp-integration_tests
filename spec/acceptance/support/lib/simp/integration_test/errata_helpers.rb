require_relative 'helpers'

module Simp
  module IntegrationTest
    module ErrataHelpers
      include Simp::IntegrationTest::Helpers

      def simp_errata(label, _opts = {})
        results = []
        case label
        when :before_yum_upgrade
          # TODO: summarize what errata was applied
          # TODO: results aren't useful
          results <<  errata_for_simp5383__yum_excludes(:add)
          results << errata_for_simp_6_2_to_6_3_upgrade__pre_yum
          results << errata_simpdev_gpg_key
        when :after_yum_upgrade
          results << errata_for_simp5383__yum_excludes(:remove)
        else
          raise "Unrecognized SIMP errata label: '#{label}'"
        end
        results.all?(&:nil?) ? nil : results
      end

      # Specific errata helpers
      # --------------------------------------------------------------------------
      # errata_* methods:
      # - execute workarounds or patches for known problems.
      # - returns nil immediately if the errata doesn't apply
      # --------------------------------------------------------------------------

      # Specific 6.1.0->* upgrade instructions, due to SIMP-5383
      # @param action [:add,:remove] Whether to `:add` or `:remove` the line
      #   `exclude=puppet-agent` from `/etc/yum.conf`
      def errata_for_simp5383__yum_excludes(action)
        return unless original_simp_version.start_with?('6.1.')
        warn '',
             '== ERRATA (SIMP-5385): Special 6.1.0 -> * upgrade instructions:',
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
        warn '',
             '== ERRATA (SIMP-????): Special <6.3 -> >=6.3 upgrade instructions:',
             '==                       * pre-yum upgrade',
             '==                       * File Watch fix',
             '==                       * https://tickets.puppetlabs.com/browse/SERVER-1971'

        # https://tickets.puppetlabs.com/browse/SERVER-1971
        # (Also see: https://tickets.puppetlabs.com/browse/SERVER-1971?focusedCommentId=492050&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-492050)
        on puppetserver, 'puppet resource file_line filewatch_fix ' \
                         'path=/etc/puppetlabs/puppetserver/services.d/ca.cfg ' \
                         'line=puppetlabs.trapperkeeper.services.watcher.filesystem-watch-service/filesystem-watch-service'

        # TODO: is this SIMP-5340 again?  If so: why did that happen to a 6.2 SUT?
        warn '',
             '== ERRATA (SIMP-????): Special <6.3 -> >=6.3 upgrade instructions:',
             '==                       * pre-yum upgrade',
             '==                       * SIMP-5340 again?'
        file = '/etc/puppetlabs/puppetserver/conf.d/web-routes.conf'
        cfg = 'web-router-service."puppetlabs.trapperkeeper.services.metrics.metrics-service/metrics-webservice"'
        value = '"/metrics"'
        on puppetserver, %(#{hocon_bin} -f file} set '#{cfg}' '#{value}' )
      end

      def errata_for_simp_6_2_to_6_3_upgrade__post_yum
        return unless [
          semver_match('< 6.3',  simp_version),
          semver_match('>= 6.3', latest_available_simp_version)
        ].all?
        warn '',
             '== ERRATA (SIMP-????): Special <6.3 -> >=6.3 upgrade instructions:',
             '==                       * post-yum upgrade',
             '==                       * SIMP-5340 again?'
      end

      def errata_simpdev_gpg_key
        facts = YAML.load(on(puppetserver, 'facter -p -y', silent: true).stdout)
        id    = facts['os']['distro']['id']
        maj   = facts['os']['distro']['release']['major']
        arch  = facts['os']['architecture']
        cmd = "set -eo pipefail; ls -1rt /var/www/yum/#{id}/#{maj}.*/#{arch}/RPM-GPG-KEY-SIMP-Dev | tail -1"
        dev_key_check = on(puppetserver, cmd, silent: true, allow_failures: true)
        return unless dev_key_check.exit_code == 0
        warn '',
             '== ERRATA (SIMP-????): RPM-GPG-KEY-SIMP-Dev in wrong directory',
             '==               * First noticed during SIMP 6.2 <-> 6.3 upgrade testing',
             new_key = dev_key_check.stdout.strip
        key_path = '/var/www/yum/SIMP-Dev/GPGKEYS/RPM-GPG-KEY-SIMP-Dev'
        # FIXME: troubleshoot why this is happening:
        #   - Is my SIMP 6.2.0 box bad?
        #     - [ ] [in progress] rebuild from SIMP 6.2.0 EL6 ISO release
        #     - [ ] test with freshly-built .box from SIMP 6.2.0 EL6 ISO release
        #   - Does this only affect EL6?
        #     - [ ] rebuild from SIMP 6.2.0 EL7 ISO release
        #     - [ ] test with freshly-built .box from SIMP 6.2.0 EL7 ISO release
        #   - Are dev GPG keys going in the wrong place?
        #     - If so: does this only happen with _dev_ GPG keys?
        on puppetserver, "cat \"#{new_key}\" > \"#{key_path}\"; chmod 0644 \"#{key_path}\""
      end
    end
  end
end

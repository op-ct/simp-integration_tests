module Simp
  module IntegrationTest
    module Helpers
      # Returns memoized puppetserver SUT
      # @return [Beaker::Host] puppetserver host object
      def puppetserver
        @puppet_server_host ||= find_at_most_one_host_with_role(hosts, 'master')
      end

      # Queries and returns the SIMP version of the given host.
      #
      # @param [String] host  the host (puppetserver())
      # @return [String] the puppetserver's original version of SIMP (when the
      #    suite began)
      def simp_version(host = puppetserver)
        on(host, 'cat /etc/simp/simp.version', silent: true).stdout.strip
      end

      # Evaluate a semver dependency expression
      #
      # @param [String] expr expression
      # @param [String] version SemVer version to evaluate
      # @param chop_suffix [Boolean] when `true`, ignores Pre-release/
      #   non-X.Y.Z suffixes like '-BETA (true)
      #
      # @return [Boolean] `true` if the `version` matched the `expr`
      #
      # @example
      #   semver_match('~> 6.2','6.3.0')               # true
      #   semver_match('~> 6.2.0','6.3.0')             # false
      #   semver_match('>= 6.3','6.3.0-Beta2')         # true
      #   semver_match('>= 6.3','6.3.0-Beta2', false ) # false (just in case)
      #
      def semver_match(expr, version, chop_suffix = true)
        version = version.sub(%r{[+-].+$}, '') if chop_suffix
        Gem::Dependency.new('', expr).match?('', version)
      end

      # Upload local RPMs into the puppetserver's yum repo
      #
      # @param [String] base_dir local directory to find RPMs (.)
      # @param [Array<String>] rpm_globs list of globs to match RPMS to upload
      #
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

      # Returns path to the `hocon` executable on a host
      #
      # @param [String] host  the host (puppetserver())
      # @return [String] path to the hocon executable
      def hocon_bin(host = puppetserver)
        hocon_bin = nil
        hocons = [
          '/opt/puppetlabs/puppet/bin/hocon',
          '/opt/puppetlabs/puppet/lib/ruby/vendor_gems/bin/hocon',
        ]
        hocons.each do |h_bin|
          r = on(host, "test -x '#{h_bin}'", silent: true, accept_all_exit_codes: true)
          if r.exit_code == 0
            hocon_bin = h_bin
            break
          end
        end
        raise "ERROR: could not find the `hocon` excutable on host '#{host}'" \
          unless hocon_bin
        hocon_bin
      end

    end
  end
end

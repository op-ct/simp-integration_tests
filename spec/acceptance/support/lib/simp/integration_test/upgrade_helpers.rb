require_relative 'helpers'

module Simp
  module IntegrationTest
    module UpgradeHelpers
      include Simp::IntegrationTest::Helpers

      # Return (and remember) the host's SIMP version at the beginning of
      #   the test.
      #
      # @param host [String] the host (puppetserver())
      # @return [String] th host's original version of SIMP
      #
      # @note: Make sure to run this method at the beginning of the suite (before
      #   upgrading) to make sure it locks onto the correct version!
      #
      def original_simp_version(host = puppetserver)
        @original_simp_version ||= {}
        @original_simp_version[host] ||= on(
          host, 'cat /etc/simp/simp.version', silent: true
        ).stdout.strip
      end

      # Queries and returns the latest available SIMP version in yum
      #
      # @param host [String] the host (puppetserver())
      # @return [String] the latest available SIMP version in yum
      def latest_available_simp_version(host = puppetserver)
        cmd = 'yum list simp | grep ^Available -A40 | grep "^simp\>"'
        on(host, cmd, silent: true).stdout.lines.map(&:strip).last.split(%r{\s+})[1]
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
    end
  end
end

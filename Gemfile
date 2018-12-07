# NOTE: SIMP Puppet rake tasks support ruby 2.1.9
# ------------------------------------------------------------------------------
gem_sources   = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)
puppet_version =  ENV.fetch('PUPPET_VERSION', '~>4.0')

gem_sources.each { |gem_source| source gem_source }

group :test do
  gem 'rake'
  gem 'puppet', puppet_version

  # Fix this when simp-rake-helpers is fully updated
  #gem 'facter', '~> 2.4.0'

  gem 'rspec'
  gem 'rubocop', '~> 0.57.0' # supports ruby 2.1
  gem 'rubocop-rspec'
  # support yard
  gem 'yard'
  gem 'redcarpet'
  gem 'github-markup'
end

group :development do
  gem 'travis'
  gem 'travis-lint'
  gem 'travish'
  gem 'pry'
  gem 'pry-doc'
  gem 'pry-reload'
end

group :system_tests do
  gem 'puppetlabs_spec_helper'
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 1.7'), :require => false
end

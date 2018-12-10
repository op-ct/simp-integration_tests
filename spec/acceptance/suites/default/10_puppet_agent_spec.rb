require 'spec_helper_acceptance'

test_name 'puppet apply smoke test'

# This smoke test establishes that the local puppet installation works before
# attempting
describe 'puppet agent runs work' do
  let(:puppet_agent_t) do
    'set -o pipefail; puppet agent -t --detailed-exitcodes'
  end

  context 'when running `puppet agent -t`' do
    it 'works with no errors' do
      agent_run_cmd = "#{puppet_agent_t} " \
                      '|& tee /root/puppet-agent.log.10.runs-idempotently'
      on(puppetserver, agent_run_cmd, :acceptable_exit_codes => [0,2]
    end

    # Strictly speaking, the `puppet agent -t` above should have been
    # idempotent, but the two runs should allow for any facter-related or dsd s
    # pre-staged updates
    it 'is idempotent' do
      agent_run_cmd = "#{puppet_agent_t} " \
                      '|& tee /root/puppet-agent.log.10.runs-idempotently'
      on(puppetserver, agent_run_cmd, :acceptable_exit_codes => [0]
    end
  end
end

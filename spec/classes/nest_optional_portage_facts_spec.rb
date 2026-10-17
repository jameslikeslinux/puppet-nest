require 'spec_helper'

# Gateway's legacy Portage reports no VIDEO_CARDS fact. Missing optional
# graphics facts must not prevent the public Nest catalog from compiling.
describe 'nest' do
  on_supported_os.each do |os, os_facts|
    next unless os.start_with?('gentoo-')

    ['server', 'workstation'].each do |variant|
      context "on #{os} #{variant} without optional Portage graphics facts" do
        let(:facts) do
          os_facts.merge(
            build: 'stage1',
            profile: { variant: variant },
            portage_video_cards: nil,
            portage_use: nil,
          )
        end

        it { is_expected.to compile.with_all_deps }
      end
    end
  end
end

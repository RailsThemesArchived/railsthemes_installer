require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Ensurer do
  before do
    setup_logger
  end

  describe :ensure_clean_install_possible do
    it 'should not do twice normally' do
      mock(Railsthemes::Ensurer).ensure_in_rails_root.times(1)
      mock(Railsthemes::Ensurer).ensure_bundle_is_up_to_date.times(1)
      mock(Railsthemes::Ensurer).ensure_railsthemes_is_not_in_gemfile.times(1)
      mock(Railsthemes::Ensurer).ensure_vcs_is_clean.times(1)
      mock(Railsthemes::Ensurer).ensure_rails_version_is_valid.times(1)
      mock(Railsthemes::Ensurer).ensure_installer_is_up_to_date.times(1)
      2.times { Railsthemes::Ensurer.ensure_clean_install_possible }
    end

    it 'should do twice if force passed' do
      mock(Railsthemes::Ensurer).ensure_in_rails_root.times(2)
      mock(Railsthemes::Ensurer).ensure_bundle_is_up_to_date.times(2)
      mock(Railsthemes::Ensurer).ensure_railsthemes_is_not_in_gemfile.times(2)
      mock(Railsthemes::Ensurer).ensure_vcs_is_clean.times(2)
      mock(Railsthemes::Ensurer).ensure_rails_version_is_valid.times(2)
      mock(Railsthemes::Ensurer).ensure_installer_is_up_to_date.times(2)
      2.times { Railsthemes::Ensurer.ensure_clean_install_possible :force => true }
    end

    it 'should not check installer version if we do not want to hit the server' do
      mock(Railsthemes::Ensurer).ensure_in_rails_root
      mock(Railsthemes::Ensurer).ensure_bundle_is_up_to_date
      mock(Railsthemes::Ensurer).ensure_railsthemes_is_not_in_gemfile
      mock(Railsthemes::Ensurer).ensure_vcs_is_clean
      mock(Railsthemes::Ensurer).ensure_rails_version_is_valid
      dont_allow(Railsthemes::Ensurer).ensure_installer_is_up_to_date
      Railsthemes::Ensurer.ensure_clean_install_possible :hit_server => false, :force => true
    end
  end

  describe :ask_to_install_unsupported do
    it 'should abort if the user does not want to continue' do
      mock(Railsthemes::Safe).yes?(/wish to install/) { false }
      mock(Railsthemes::Safe).log_and_abort('Halting.')
      Railsthemes::Ensurer.ask_to_install_unsupported
    end

    it 'should continue if the user wants to continue' do
      mock(Railsthemes::Safe).yes?(/wish to install/) { true }
      dont_allow(Railsthemes::Safe).log_and_abort(anything)
      Railsthemes::Ensurer.ask_to_install_unsupported
    end
  end

  describe '#ensure_installer_is_up_to_date' do
    it 'should abort with message if the current installer version is < server recommendation' do
      FakeWeb.register_uri :get, /\/installer\/version$/, :body => '1.0.4'
      mock(Railsthemes::Safe).log_and_abort(anything) do |message|
        message.should match(/Your version is older than the recommended version/)
        message.should match(/Your version: 1\.0\.3/)
        message.should match(/Recommended version: 1\.0\.4/)
      end
      with_installer_version '1.0.3' do
        Railsthemes::Ensurer.ensure_installer_is_up_to_date
      end
    end

    it 'should not abort if the current installer version equals server recommendation' do
      FakeWeb.register_uri :get, /\/installer\/version$/, :body => '1.0.4'
      dont_allow(Railsthemes::Safe).log_and_abort(anything)
      with_installer_version '1.0.4' do
        Railsthemes::Ensurer.ensure_installer_is_up_to_date
      end
    end

    it 'should return nothing if the current installer version is > server recommendation' do
      FakeWeb.register_uri :get, /\/installer\/version$/, :body => '1.0.4'
      dont_allow(Railsthemes::Safe).log_and_abort(anything)
      with_installer_version '1.0.5' do
        Railsthemes::Ensurer.ensure_installer_is_up_to_date
      end
    end

    it 'should return an error message on any HTTP errors' do
      FakeWeb.register_uri :get, /\/installer\/version$/,
        :body => '', :status => ['401', 'Unauthorized']
      mock(Railsthemes::Safe).log_and_abort(/issue checking your installer version/)
      Railsthemes::Ensurer.ensure_installer_is_up_to_date
    end
  end

  describe :ensure_vcs_is_clean do
    context 'when Git used' do
      before do
        Dir.mkdir('.git')
      end

      it 'should log error and abort when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '# modified: installer_spec.rb' }
        mock(Railsthemes::Safe).log_and_abort(anything) do |message|
          message.should match /Git reports/
          message.should match /# modified: installer_spec\.rb/
          message.should match /roll back or commit/
        end
        Railsthemes::Ensurer.ensure_vcs_is_clean
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '' }
        dont_allow(Railsthemes::Safe).log_and_abort(anything)
        Railsthemes::Ensurer.ensure_vcs_is_clean
      end
    end

    context 'when Mercurial used' do
      before do
        Dir.mkdir('.hg')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('hg status') { '? test.txt' }
        mock(Railsthemes::Safe).log_and_abort(anything) do |message|
          message.should match /Mercurial reports/
          message.should match /\? test\.txt/
          message.should match /roll back or commit/
        end
        Railsthemes::Ensurer.ensure_vcs_is_clean
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('hg status') { '' }
        dont_allow(Railsthemes::Safe).log_and_abort(anything)
        Railsthemes::Ensurer.ensure_vcs_is_clean
      end
    end

    context 'when Subversion used' do
      before do
        Dir.mkdir('.svn')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('svn status') { 'M something.txt' }
        mock(Railsthemes::Safe).log_and_abort(anything) do |message|
          message.should match /Subversion reports/
          message.should match /M something\.txt/
          message.should match /roll back or commit/
        end
        Railsthemes::Ensurer.ensure_vcs_is_clean
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('svn status') { '' }
        Railsthemes::Ensurer.ensure_vcs_is_clean
      end
    end
  end

  describe '#rails_version' do
    it 'should return the right version' do
      gemfile = using_gem_specs :rails => '3.0.1'
      Railsthemes::Ensurer.rails_version(gemfile).version.should == '3.0.1'
    end

    it 'should return nil if there is no rails present' do
      gemfile = using_gem_specs
      Railsthemes::Ensurer.rails_version(gemfile).should be_nil
    end
  end

  describe '#ensure_rails_version_is_valid' do
    it 'should ask the user if they still want to install when the gemfile does not exist' do
      stub(Railsthemes::Ensurer).rails_version { Gem::Version.new('3.2.0') }
      mock(Railsthemes::Ensurer).ask_to_install_unsupported
      Railsthemes::Ensurer.ensure_rails_version_is_valid
    end

    context 'when gemfile exists' do
      before do
        FileUtils.touch('Gemfile.lock')
      end

      it 'should ask the user if they still want to install when the rails version is < 3.1' do
        stub(Railsthemes::Ensurer).rails_version { Gem::Version.new('3.0.9') }
        mock(Railsthemes::Ensurer).ask_to_install_unsupported
        Railsthemes::Ensurer.ensure_rails_version_is_valid
      end

      it 'should not ask if they still want to install when the rails version is supported' do
        stub(Railsthemes::Ensurer).rails_version { Gem::Version.new('3.1.0') }
        dont_allow(Railsthemes::Ensurer).ask_to_install_unsupported
        Railsthemes::Ensurer.ensure_rails_version_is_valid
      end
    end
  end

  describe :ensure_bundle_is_up_to_date do
    it 'should not log message and abort if the bundle is up to date' do
      mock(Railsthemes::Safe).system_call('bundle check') { "The Gemfile's dependencies are satisfied" }
      dont_allow(Railsthemes::Safe).log_and_abort(anything)
      Railsthemes::Ensurer.ensure_bundle_is_up_to_date

    end

    it 'should log message and abort if the bundle is not up to date' do
      mock(Railsthemes::Safe).system_call('bundle check') { 'test not up to date' }
      mock(Railsthemes::Safe).log_and_abort(/test not up to date/)
      Railsthemes::Ensurer.ensure_bundle_is_up_to_date
    end
  end

  describe :ensure_railsthemes_is_not_in_gemfile do
    it 'should log and abort if railsthemes is in the Gemfile.lock' do
      mock(Railsthemes::Safe).log_and_abort(/in your Gemfile/i)
      gemfile = using_gem_specs :railsthemes => '1.0.4'
      Railsthemes::Ensurer.ensure_railsthemes_is_not_in_gemfile gemfile
    end

    it 'should do nothing if railsthemes is not in the Gemfile.lock' do
      dont_allow(Railsthemes::Safe).log_and_abort(anything)
      gemfile = using_gem_specs
      Railsthemes::Ensurer.ensure_railsthemes_is_not_in_gemfile gemfile
    end
  end
end

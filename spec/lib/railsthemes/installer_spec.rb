require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Installer do
  before do
    setup_logger
    @installer = Railsthemes::Installer.new
    stub(@installer).ensure_in_rails_root
    @tempdir = stub_tempdir
    FileUtils.touch('Gemfile.lock')
  end

  describe 'popping up the documentation on a successful install' do
    before do
      # set up files for copying
      FileUtils.mkdir_p('filepath/base')
      FileUtils.touch('filepath/base/a')
      FileUtils.touch('filepath/base/b')
      FileUtils.mkdir_p('filepath/gems')
    end

    it 'should not pop it up when the user specified not to pop it up' do
      @installer.doc_popup = false
      dont_allow(@installer).popup_documentation
      @installer.install_from_file_system 'filepath'
    end

    it 'should pop it up when the user did not specify to not pop it up' do
      mock(@installer).popup_documentation
      @installer.install_from_file_system 'filepath'
    end
  end

  describe 'end to end operation' do
    def verify_end_to_end_operation
      ['app/assets/images/image1.png',
       'app/assets/images/bg/sprite.png',
       'app/assets/javascripts/jquery.dataTables.js',
       'app/assets/javascripts/scripts.js.erb',
       'app/assets/stylesheets/style.css.erb',
       'app/views/layouts/_interior_sidebar.html.erb',
       'app/views/layouts/application.html.erb',
       'app/views/layouts/homepage.html.erb'].each do |filename|
         File.should exist(filename), "#{filename} was not present"
      end
      File.open('app/assets/stylesheets/style.css.erb').each do |line|
        line.should match /style.css.erb/
      end
    end

    before do
      stub(@installer).post_copying_changes
      FakeFS::FileSystem.clone('spec/fixtures')
      # should add some gems to the gemfile here and test gem installation
    end

    it 'should extract correctly from directory' do
      filename = 'spec/fixtures/blank-assets'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end

    # does not work on Windows, NotImplementedError in tar module
    it 'should extract correctly from archive' do
      filename = 'spec/fixtures/blank-assets.tar.gz'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end
  end

  describe :ask_to_install_unsupported do
    it 'should abort if the user does not want to continue' do
      mock(Railsthemes::Safe).yes?(/wish to install/) { false }
      mock(Railsthemes::Safe).log_and_abort('Halting.')
      @installer.ask_to_install_unsupported 'code'
    end

    it 'should continue if the user wants to continue' do
      mock(Railsthemes::Safe).yes?(/wish to install/) { true }
      any_instance_of(Railsthemes::ThemeInstaller) do |ti|
        mock(ti).install_from_server('code')
      end
      @installer.ask_to_install_unsupported 'code'
    end
  end

  describe :install_from_code do
    it 'should abort if the VCS is not clean' do
      mock(@installer).check_vcs_status { 'msg' }
      mock(Railsthemes::Safe).log_and_abort('msg')
      @installer.install_from_code 'thecode'
    end

    it 'should abort if the installer version is not up-to-date' do
      mock(@installer).check_vcs_status
      mock(@installer).check_installer_version { 'msg' }
      mock(Railsthemes::Safe).log_and_abort('msg')
      @installer.install_from_code 'thecode'
    end

    it 'should ask the user if they still want to install when a Gemfile.lock is not present' do
      File.unlink('Gemfile.lock')
      mock(@installer).check_vcs_status
      mock(@installer).check_installer_version
      mock(@installer).ask_to_install_unsupported 'thecode'
      @installer.install_from_code 'thecode'
    end

    it 'should ask the user if they still want to install when the rails version is < 3.1' do
      mock(@installer).check_vcs_status
      mock(@installer).check_installer_version
      mock(@installer).rails_version { Gem::Version.new('3.0.9') }
      mock(@installer).ask_to_install_unsupported 'thecode'
      @installer.install_from_code 'thecode'
    end

    it 'should install from the server otherwise' do
      mock(@installer).check_vcs_status
      mock(@installer).check_installer_version
      mock(@installer).rails_version { Gem::Version.new('3.1.0') }
      any_instance_of(Railsthemes::ThemeInstaller) do |ti|
        mock(ti).install_from_server 'thecode'
      end
      @installer.install_from_code 'thecode'
    end
  end

  def with_installer_version version, &block
    old_version = Railsthemes::VERSION
    Railsthemes.send(:remove_const, 'VERSION')
    Railsthemes.const_set('VERSION', version)

    block.call

    Railsthemes.send(:remove_const, 'VERSION')
    Railsthemes.const_set('VERSION', old_version)
  end

  describe '#check_installer_version' do
    it 'should return message if the current installer version is < server recommendation' do
      FakeWeb.register_uri :get, /\/installer\/version$/, :body => '1.0.4'
      with_installer_version '1.0.3' do
        result = @installer.check_installer_version
        result.should_not be_nil
        result.should match(/Your version is older than the recommended version/)
        result.should match(/Your version: 1\.0\.3/)
        result.should match(/Recommended version: 1\.0\.4/)
      end
    end

    it 'should return nothing if the current installer version is = server recommendation' do
      FakeWeb.register_uri :get, /\/installer\/version$/, :body => '1.0.4'
      with_installer_version '1.0.4' do
        result = @installer.check_installer_version
        result.should be_nil
      end
    end

    it 'should return nothing if the current installer version is > server recommendation' do
      FakeWeb.register_uri :get, /\/installer\/version$/, :body => '1.0.4'
      with_installer_version '1.0.5' do
        result = @installer.check_installer_version
        result.should be_nil
      end
    end

    it 'should return an error message on any HTTP errors' do
      FakeWeb.register_uri :get, /\/installer\/version$/,
        :body => '', :status => ['401', 'Unauthorized']
      @installer.check_installer_version.should_not be_nil
    end
  end

  describe :check_vcs_status do
    context 'when Git used' do
      before do
        Dir.mkdir('.git')
      end

      it 'should return false, issues when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '# modified: installer_spec.rb' }
        result = @installer.check_vcs_status
        result.should match /Git reports/
        result.should match /# modified: installer_spec\.rb/
        result.should match /roll back or commit/
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '' }
        @installer.check_vcs_status.should be_nil
      end
    end

    context 'when Mercurial used' do
      before do
        Dir.mkdir('.hg')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('hg status') { '? test.txt' }
        result = @installer.check_vcs_status
        result.should_not be_nil
        result.should match /Mercurial reports/
        result.should match /\? test\.txt/
        result.should match /roll back or commit/
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('hg status') { '' }
        @installer.check_vcs_status.should be_nil
      end
    end

    context 'when Subversion used' do
      before do
        Dir.mkdir('.svn')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('svn status') { 'M something.txt' }
        result = @installer.check_vcs_status
        result.should match /Subversion reports/
        result.should match /M something\.txt/
        result.should match /roll back or commit/
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('svn status') { '' }
        @installer.check_vcs_status.should be_nil
      end
    end
  end

  describe '#rails_version' do
    it 'should return the right version' do
      gemfile = using_gem_specs :rails => '3.0.1'
      @installer.rails_version(gemfile).version.should == '3.0.1'
    end

    it 'should return nil if there is no rails present' do
      gemfile = using_gem_specs
      @installer.rails_version(gemfile).should be_nil
    end
  end

  describe 'popup_documentation' do
    it 'should not open if the style guide does not exist' do
      dont_allow(Launchy).open(anything)
      @installer.popup_documentation
    end

    it 'should open the style guide correctly if it exists' do
      FileUtils.mkdir_p('doc')
      filename = 'doc/Theme_Envy_Usage_And_Style_Guide.html'
      FileUtils.touch(filename)
      mock(Launchy).open(filename)
      @installer.popup_documentation
    end
  end
end

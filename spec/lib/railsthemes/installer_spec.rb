require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Installer do
  before do
    setup_logger
    @installer = Railsthemes::Installer.new
    @tempdir = stub_tempdir

    # would be interesting to see if we still need these
    stub(@installer).ensure_in_rails_root
    FileUtils.touch('Gemfile.lock')
  end

  describe :install_from_file_system do
    before do
      FakeFS::FileSystem.clone('spec/fixtures')
      stub(Railsthemes::Ensurer).ensure_clean_install_possible
      stub(Railsthemes::Utils).get_primary_configuration(anything) { ['erb', 'css'] }
    end

    describe 'installing theme' do
      before do
        stub(@installer.email_installer).install_from_file_system(anything)
      end

      it 'should install the right theme version' do
        mock(@installer.theme_installer).install_from_file_system('spec/fixtures/blank-assets/erb-css')
        @installer.install_from_file_system 'spec/fixtures/blank-assets'
      end

      it 'should install the right theme version if it is an archive in that directory' do
        mock(@installer.theme_installer).install_from_file_system('spec/fixtures/blank-assets-archived/erb-css.tar.gz')
        stub(@installer.email_installer).install_from_file_system(anything)
        @installer.install_from_file_system 'spec/fixtures/blank-assets-archived'
      end
    end

    describe 'installing email theme' do
      before do
        stub(@installer.theme_installer).install_from_file_system(anything)

      end
      it 'should install the email theme if present' do
        mock(@installer.email_installer).install_from_file_system('spec/fixtures/blank-assets/email')
        @installer.install_from_file_system 'spec/fixtures/blank-assets'
      end

      it 'should install the archived email theme if present' do
        mock(@installer.email_installer).install_from_file_system('spec/fixtures/blank-assets-archived/email.tar.gz')
        @installer.install_from_file_system 'spec/fixtures/blank-assets-archived'
      end
    end
  end

  # should probably move documentation stuff to another class
  describe 'popping up the documentation' do
    context 'when installing from the file system' do
      before do
        FakeFS::FileSystem.clone('spec/fixtures')
        stub(Railsthemes::Ensurer).ensure_clean_install_possible
        stub(@installer.theme_installer).install_from_file_system(anything)
        stub(@installer.email_installer).install_from_file_system(anything)
      end

      it 'should not pop it up when the user specified not to pop it up' do
        @installer.doc_popup = false
        dont_allow(@installer).popup_documentation
        @installer.install_from_file_system 'spec/fixtures/blank-assets'
      end

      it 'should pop it up when the user did not specify to not pop it up' do
        mock(@installer).popup_documentation
        @installer.install_from_file_system 'spec/fixtures/blank-assets'
      end
    end

    context 'when installing from a code' do
      before do
        stub(Railsthemes::Ensurer).ensure_clean_install_possible
      end

      it 'should not pop it up when the user specified not to pop it up' do
        @installer.doc_popup = false
        mock(@installer.theme_installer).install_from_server('code')
        dont_allow(@installer).popup_documentation
        @installer.install_from_code 'code'
      end

      it 'should pop it up when the user did not specify to not pop it up' do
        mock(@installer.theme_installer).install_from_server('code')
        mock(@installer).popup_documentation
        @installer.install_from_code 'code'
      end
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

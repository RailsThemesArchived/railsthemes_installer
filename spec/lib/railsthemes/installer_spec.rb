require 'spec_helper'
require 'railsthemes'
require 'json'

describe Railsthemes::Installer do
  before do
    setup_logger
    @installer = Railsthemes::Installer.new
    @tempdir = stub_tempdir

    # would be interesting to see if we still need these
    stub(Railsthemes::Ensurer).ensure_clean_install_possible
    FileUtils.touch('Gemfile.lock')
  end

  describe :install_from_file_system do
    before do
      FakeFS::FileSystem.clone('spec/fixtures')
      stub(Railsthemes::Utils).get_primary_configuration { ['erb', 'css'] }
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

  describe '#download_and_install_from_hash' do
    it 'should download and install theme when theme specified' do
      mock(Railsthemes::Utils).download(:url => 'theme_url', :save_to => "dir/erb-css.tar.gz")
      @installer.download_from_hash({'theme' => 'theme_url'}, 'dir')
    end
  end

  describe '#install_from_code' do
    before do
      mock(@installer).send_gemfile('panozzaj@gmail.com:code')
    end

    it 'should do something'
  end

  describe '#get_download_hash' do
    it 'should download the file correctly when valid configuration' do
      FakeWeb.register_uri :get,
        /download\?code=panozzaj@gmail.com:code&config=haml,scss&v=2/,
        :body => { 'theme' => 'auth_url' }.to_json
      mock(Railsthemes::Utils).get_primary_configuration { ['haml', 'scss'] }
      result = @installer.get_download_hash 'panozzaj@gmail.com:code'
      result.should == { 'theme' => 'auth_url' }
    end

    it 'should fail with an error message on any error message' do
      FakeWeb.register_uri :get,
        'https://railsthemes.com/download?code=panozzaj@gmail.com:code&config=',
        :body => '', :status => ['401', 'Unauthorized']
      mock(Railsthemes::Utils).get_primary_configuration { [] }
      mock(Railsthemes::Safe).log_and_abort(/didn't recognize/)
      @installer.install_from_code 'panozzaj@gmail.com:code'
    end
  end

  describe :send_gemfile do
    before do
      File.open('Gemfile.lock', 'w') do |file|
        file.puts "GEM\n  remote: https://rubygems.org/"
      end
    end

    it 'should hit the server with the Gemfile and return the results, arrayified' do
      FakeFS.deactivate! # has an issue with generating tmpfiles otherwise
      params = { :code => 'panozzaj@gmail.com:code', :gemfile_lock => File.new('Gemfile.lock', 'rb') }
      FakeWeb.register_uri :post, 'https://railsthemes.com/gemfiles/parse',
        :body => 'haml,scss', :parameters => params
      @installer.send_gemfile('panozzaj@gmail.com:code')
    end

    it 'should return a blank array when there are issues' do
      FakeFS.deactivate! # has an issue with generating tmpfiles otherwise
      FakeWeb.register_uri :post, 'https://railsthemes.com/gemfiles/parse',
        :body => '', :parameters => :any, :status => ['401', 'Unauthorized']
      @installer.send_gemfile('panozzaj@gmail.com:code')
    end
  end

end

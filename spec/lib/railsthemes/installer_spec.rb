require 'spec_helper'
require 'json'

describe Railsthemes::Installer do
  before do
    @installer = Railsthemes::Installer.new
    @tempdir = stub_tempdir

    stub(Railsthemes::Ensurer).ensure_clean_install_possible
    stub(Railsthemes::Safe).system_call('bundle')
  end

  describe 'initialization' do
    describe 'server' do
      it 'should default to production' do
        installer = Railsthemes::Installer.new
        installer.server.should == 'https://railsthemes.com'
      end

      it 'should be right when in staging' do
        installer = Railsthemes::Installer.new(:staging => true)
        installer.server.should == 'http://staging.railsthemes.com'
      end

      it 'should be right when server passed in' do
        installer = Railsthemes::Installer.new(:server => 'http://example.com')
        installer.server.should == 'http://example.com'
      end
    end

    describe 'documentation popup' do
      it 'should pop up when it is not mentioned' do
        installer = Railsthemes::Installer.new
        installer.doc_popup.should be_true
      end

      it 'should not pop up when configured to not pop up' do
        installer = Railsthemes::Installer.new(:no_doc_popup => true)
        installer.doc_popup.should be_false
      end

      it 'should pop up when configured to pop up' do
        installer = Railsthemes::Installer.new(:no_doc_popup => false)
        installer.doc_popup.should be_true
      end
    end
  end

  # this should arguably be an integration test, but I'm not sure how
  # fakefs + running arbitrary binaries will work out
  describe 'end to end behavior' do
    before do
      stub(@installer).post_copying_changes
      FakeFS::FileSystem.clone('spec/fixtures')
    end

    def verify_end_to_end_operation
      [
       'app/controllers/controller1.rb',
       'doc/some_doc.md',
       'app/helpers/helper1.rb',
       'app/assets/images/image1.jpg',
       'app/assets/javascripts/file1.js',
       'app/views/layouts/layout1.html.haml',
       'app/mailers/mailer.rb',
       'app/assets/stylesheets/stylesheet1.css.scss',
      ].each do |filename|
        File.should exist(filename), "#{filename} was expected but not present"
      end
    end

    it 'should extract correctly from directory' do
      filename = 'spec/fixtures/blank-assets/tier1-erb-scss'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end

    # this spec does not work on Windows, NotImplementedError in tar module
    it 'should extract correctly from archive' do
      filename = 'spec/fixtures/blank-assets-archived/tier1-erb-scss'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end
  end

  describe :install_from_file_system do
    before do
      FakeFS::FileSystem.clone('spec/fixtures')
      @theme_installer = @installer.theme_installer
      @email_installer = @installer.email_installer
    end

    context 'when the filepath represents an archive file' do
      let(:archive) { 'tarfile.tar.gz' }

      it 'should extract the archive file to a temp directory if the archive exists' do
        FileUtils.touch archive
        mock(@installer).install_from_archive archive
        @installer.install_from_file_system 'tarfile'
      end

      it 'should extract the archive file to a temp directory if the archive exists' do
        FileUtils.touch archive
        mock(@installer).install_from_archive archive
        @installer.install_from_file_system 'tarfile.tar.gz'
      end
    end

    context 'when the filepath has Windows directory separators' do
      it 'should handle windows style paths' do
        create_file 'subdir/theme/text.txt'
        mock(@theme_installer).install_from_file_system('subdir/theme')
        @installer.install_from_file_system('subdir\theme')
      end
    end

    describe 'installing theme' do
      it 'should install the right theme version' do
        mock(@theme_installer).install_from_file_system('spec/fixtures/blank-assets/tier1-erb-scss')
        mock(@email_installer).install_from_file_system('spec/fixtures/blank-assets/tier1-erb-scss')
        @installer.install_from_file_system 'spec/fixtures/blank-assets/tier1-erb-scss'
      end

      it 'should install the right theme version if it is an archive in that directory' do
        mock(@theme_installer).install_from_file_system('tmp')
        mock(@email_installer).install_from_file_system('tmp')
        @installer.install_from_file_system 'spec/fixtures/blank-assets-archived/tier1-erb-scss'
      end
    end
  end

  describe :install_from_archive do
    # this spec does not work on Windows, NotImplementedError in tar module
    it 'should extract and then install from that extracted directory' do
      filename = 'spec/fixtures/blank-assets-archived/tier1-erb-scss.tar.gz'
      FakeFS::FileSystem.clone(filename)
      mock(@installer).install_from_file_system @tempdir
      @installer.install_from_archive filename
    end
  end

  # should probably move documentation stuff to another class
  describe 'popping up the documentation' do
    context 'when installing from the file system' do
      before do
        FakeFS::FileSystem.clone('spec/fixtures')
        stub(@installer.theme_installer).install_from_file_system(anything)
      end

      it 'should not pop it up when the user specified not to pop it up' do
        @installer.doc_popup = false
        dont_allow(@installer).popup_documentation
        @installer.install_from_file_system 'spec/fixtures/blank-assets/tier1-erb-scss'
      end

      it 'should pop it up when the user did not specify to not pop it up' do
        mock(@installer).popup_documentation
        @installer.install_from_file_system 'spec/fixtures/blank-assets/tier1-erb-scss'
      end
    end
  end

  describe '#popup_documentation' do
    it 'should not open if the style guide does not exist' do
      dont_allow(Launchy).open(anything)
      @installer.popup_documentation
    end

    it 'should open guides correctly if they exist' do
      filename = 'doc/railsthemes_themename/test.html'
      create_file(filename)
      mock(Launchy).open(filename)
      @installer.popup_documentation
    end

    it 'should open docs from the latest folder' do
      create_file(old = 'doc/railsthemes_oldtheme/test.html')
      create_file(new = 'doc/railsthemes_newtheme/test.html')
      dont_allow(Launchy).open(old)
      mock(Launchy).open(new)
      @installer.popup_documentation
    end

    it 'should open multiple docs' do
      create_file(new1 = 'doc/railsthemes_newtheme/test1.html')
      create_file(new2 = 'doc/railsthemes_newtheme/test2.html')
      mock(Launchy).open(new1)
      mock(Launchy).open(new2)
      @installer.popup_documentation
    end
  end

  describe '#download_from_url' do
    it 'should download theme' do
      mock(Railsthemes::Utils).download(:url => 'theme url', :save_to => "dir/rt-archive.tar.gz")
      @installer.download_from_url('theme url', 'dir')
    end
  end

  describe '#install_from_code' do
    before do
      mock(@installer).send_gemfile('code')
    end

    it 'should download and install when the code is recognized' do
      mock(@installer).get_download_url('code') { 'url' }
      mock(@installer).download_from_url('url', @tempdir)
      mock(@installer).install_from_file_system("#{@tempdir}/rt-archive")
      @installer.install_from_code 'code'
    end

    it 'should print an error message when the code is not recognized' do
      mock(@installer).get_download_url('code') { nil }
      dont_allow(@installer).download_from_url(anything, anything)
      dont_allow(@installer).install_from_file_system(anything)
      mock(Railsthemes::Safe).log_and_abort(/didn't recognize/)
      @installer.install_from_code 'code'
    end
  end

  describe '#get_download_url' do
    it 'should return the url when valid configuration' do
      stub(Railsthemes::Utils).get_primary_configuration { ['haml', 'scss'] }
      FakeWeb.register_uri :get,
        /download\?code=panozzaj@gmail.com:code&config=haml,scss&v=2/,
        :body => 'auth_url'
      result = @installer.get_download_url 'panozzaj@gmail.com:code'
      result.should == 'auth_url'
    end

    it 'should return nil when cannot download' do
      stub(Railsthemes::Utils).get_primary_configuration { [] }
      FakeWeb.register_uri :get,
        'https://railsthemes.com/download?code=panozzaj@gmail.com:code&config=&v=2',
        :body => 'Unauthorized', :status => ['401', 'Unauthorized']
      result = @installer.get_download_url 'panozzaj@gmail.com:code'
      result.should == nil
    end
  end

  describe :send_gemfile do
    context 'without Gemfile.lock present' do
      it 'should not hit the server and should return nil' do
        result = @installer.send_gemfile('panozzaj@gmail.com:code')
        result.should be_nil
      end
    end

    context 'with Gemfile.lock present' do
      before do
        FakeFS.deactivate! # has an issue with generating tmpfiles otherwise
        # this gives us a Gemfile.lock since we have it on the actual filesystem
      end

      it 'should hit the server with the Gemfile and return the results, arrayified' do
        params = { :code => 'panozzaj@gmail.com:code', :gemfile_lock => File.new('Gemfile.lock', 'rb') }
        FakeWeb.register_uri :post, 'https://railsthemes.com/gemfiles/parse',
          :body => 'haml,scss', :parameters => params
        @installer.send_gemfile('panozzaj@gmail.com:code')
      end

      it 'should return a blank array when there are issues' do
        FakeWeb.register_uri :post, 'https://railsthemes.com/gemfiles/parse',
          :body => '', :parameters => :any, :status => ['401', 'Unauthorized']
        @installer.send_gemfile('panozzaj@gmail.com:code')
      end
    end
  end
end

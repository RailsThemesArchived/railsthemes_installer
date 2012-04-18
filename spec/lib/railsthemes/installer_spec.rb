require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Installer do
  before do
    @logger = Logger.new(File.join Dir.tmpdir, 'railsthemes.log')
    @installer = Railsthemes::Installer.new @logger
    stub(@installer).ensure_in_rails_root
    stub(@installer).generate_tempdir_name { '/tmp' }
  end

  describe :install_from_file_system do
    context 'when the filepath is a directory' do
      it 'should copy the files from that directory into the Rails app' do
        FileUtils.mkdir('filepath')
        FileUtils.touch('filepath/a')
        FileUtils.touch('filepath/b')
        mock(@installer).post_copying_changes

        mock(@installer).copy_with_backup('filepath', /a$/)
        mock(@installer).copy_with_backup('filepath', /b$/)
        @installer.install_from_file_system('filepath')
      end
    end

    context 'when the filepath is an archive file' do
      it 'should extract the archive file to a temp directory if the archive exists' do
        archive = 'tarfile.tar.gz'
        FileUtils.touch archive
        mock(@installer).install_from_archive archive
        @installer.install_from_file_system archive
      end

      it 'should print an error message and exit if the archive cannot be found' do
        mock(Railsthemes::Safe).log_and_abort(/Cannot find/)
        @installer.install_from_file_system 'tarfile.tar.gz'
      end
    end

    context 'otherwise' do
      it 'should print usage and report an error reading the file' do
        mock(@installer).print_usage_and_abort(/either/)
        @installer.install_from_file_system("does not exist")
      end
    end
  end

  describe :copy_with_backup do
    before do
      FileUtils.mkdir 'fp'
      FileUtils.touch 'fp/file'
    end

    context 'when the destination file does not exist' do
      it 'should copy the file to the local directory' do
        @installer.copy_with_backup 'fp', 'file'
        File.exists?('file').should be_true
      end
    end

    context 'when the destination file exists' do
      before do
        FileUtils.touch 'file'
      end

      it 'should make a backup of existing file if it is present' do
        @installer.copy_with_backup 'fp', 'file'
        File.exists?('file').should be_true
        File.exists?('file.old').should be_true
      end
    end
  end

  describe :install_from_archive do
    it 'should extract the archive correctly' do
      mock(@installer).install_from_file_system '/tmp'
      mock(@installer).untar_string('filepath', anything) { 'untar string' }
      mock(Railsthemes::Safe).system_call('untar string')
      @installer.install_from_archive 'filepath'
    end
  end

  describe :untar_string do
    it 'should return correct value for *.tar.gz file' do
      result = @installer.untar_string 'file.tar.gz', 'newdirpath'
      result.should == 'tar -zxf file.tar.gz'
    end
  end

  describe :archive? do
    it 'should be true for tar.gz file' do
      @installer.archive?('test/a/b/c/d.tar.gz').should be_true
    end

    it 'should be false for other extensions' do
      @installer.archive?('test/a/b/c.tar/d.zip').should be_false
    end
  end

  describe 'end to end operation' do
    def verify_end_to_end_operation
      ['app/assets/images/image1.png',
       'app/assets/images/bg/sprite.png',
       'app/assets/javascripts/jquery.dataTables.js',
       'app/assets/javascripts/scripts.js.erb',
       'app/assets/stylesheets/style.css.erb',
       'app/views/layouts/_interior_sidebar.html.html.erb',
       'app/views/layouts/application.html.erb',
       'app/views/layouts/homepage.html.erb'].each do |filename|
         File.exist?(filename).should be_true, "#{filename} was not present"
      end
      File.open('app/assets/stylesheets/style.css.erb').each do |line|
        line.should match /style.css.erb/
      end
    end

    # see https://github.com/defunkt/fakefs/issues/121 for the reason for this
    def stubby filepath
      stub(@installer).files_under(filepath) {
        ["app/assets/images/bg/sprite.png",
         "app/assets/images/image1.png",
         "app/assets/javascripts/jquery.dataTables.js",
         "app/assets/javascripts/scripts.js.erb",
         "app/assets/stylesheets/style.css.erb",
         "app/views/layouts/_interior_sidebar.html.html.erb",
         "app/views/layouts/application.html.erb",
         "app/views/layouts/homepage.html.erb"]
      }
    end

    before do
      stub(@installer).post_copying_changes
      FakeFS::FileSystem.clone('spec/fixtures')
    end

    def print_directory dir
      Dir.entries(dir).each do |entry|
        next if entry == '..' || entry == '.'
        filename = File.join(dir, entry)
        if File.directory?(filename)
          print_directory filename
        elsif File.file?(filename)
          puts "file in print_directory: #{filename}"
        end
      end
    end

    it 'should extract correctly from directory' do
      filename = 'spec/fixtures/blank-assets'
      stubby filename
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end

    #it 'should extract correctly from zipped archive file' do
    #  filename = 'spec/fixtures/blank-assets.tar.gz'
    #  stubby /\/tmp/
    #  @installer.install '--file', filename
    #  print_directory('/tmp')
    #  verify_end_to_end_operation
    #end
  end

  describe :gems_to_use do
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
      @installer.gems_to_use('panozzaj@gmail.com:code').should =~ [:haml, :scss]
    end

    it 'should return a blank array when there are issues' do
      FakeFS.deactivate! # has an issue with generating tmpfiles otherwise
      FakeWeb.register_uri :post, 'https://railsthemes.com/gemfiles/parse',
        :body => '', :parameters => :any, :status => ['401', 'Unauthorized']
      @installer.gems_to_use('panozzaj@gmail.com:code').should == []
    end
  end

  describe :download_from_code do
    context 'normal operation' do
      it 'should download the file correctly' do
        FakeWeb.register_uri :get,
          /download\?code=panozzaj@gmail.com:code&config=haml,scss/,
          :body => 'auth_url'
        mock(@installer).gems_to_use('panozzaj@gmail.com:code') { [:haml, :scss] }
        mock(Railsthemes::Utils).download_file_to('auth_url', '/tmp/archive.tar.gz')
        mock(@installer).check_vcs_status
        mock(@installer).install_from_archive '/tmp/archive.tar.gz'
        @installer.download_from_code 'panozzaj@gmail.com:code'
      end
    end

    context 'any issue' do # invalid code, server error, etc.
      it 'should fail with an error message' do
        FakeWeb.register_uri :get,
          'https://railsthemes.com/download?code=panozzaj@gmail.com:code&config=',
          :body => '', :status => ['401', 'Unauthorized']
        mock(@installer).gems_to_use('panozzaj@gmail.com:code') { [] }
        mock(Railsthemes::Safe).log_and_abort(/didn't understand/)
        @installer.download_from_code 'panozzaj@gmail.com:code'
      end
    end
  end

  describe :check_vcs_status do
    context 'when git used' do
      before do
        Dir.mkdir('.git')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '# modified: installer_spec.rb' }
        mock(Railsthemes::Safe).log_and_abort(/pending changes/)
        @installer.check_vcs_status
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '' }
        @installer.check_vcs_status
      end
    end

    context 'when hg used' do
      before do
        Dir.mkdir('.hg')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('hg status') { '? test.txt' }
        mock(Railsthemes::Safe).log_and_abort(/pending changes/)
        @installer.check_vcs_status
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('hg status') { '' }
        @installer.check_vcs_status
      end
    end

    context 'when subversion used' do
      before do
        Dir.mkdir('.svn')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('svn status') { 'M something.txt' }
        mock(Railsthemes::Safe).log_and_abort(/pending changes/)
        @installer.check_vcs_status
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('svn status') { '' }
        @installer.check_vcs_status
      end
    end
  end
end

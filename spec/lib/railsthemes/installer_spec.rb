require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Installer do
  before do
    @logger = Logger.new(File.join Dir.tmpdir, 'railsthemes.log')
    @installer = Railsthemes::Installer.new @logger
  end

  describe :execute do
    it 'should print usage if no params given' do
      mock(@installer).print_usage
      @installer.execute
    end

    it 'should run the installer if installer is the first parameter' do
      mock(@installer).install 'a', 'b', 'c'
      @installer.execute(['install', 'a', 'b', 'c'])
    end
  end

  describe :install do
    before do
      stub(@installer).ensure_in_rails_root
    end

    context 'when --file is given as a parameter' do
      it 'should read from the file argument' do
        mock(@installer).install_from_file_system('filepath')
        @installer.install '--file', 'filepath'
      end

      it 'should print usage and error message and exit if filepath is nil' do
        dont_allow(@installer).install_from_file_system(anything)
        dont_allow(@installer).download_from_hash(anything)
        mock(@installer).print_usage_and_abort(/parameter/)
        @installer.install '--file'
      end
    end

    context 'hash given' do
      it 'should download that hash' do
        mock(@installer).download_from_hash('hash')
        @installer.install 'hash'
      end
    end

    context '--help given' do
      it 'should print the usage' do
        mock(@installer).print_usage
        @installer.install '--help'
      end
    end

    context 'when no parameters given' do
      it 'should print usage and error message and exit' do
        dont_allow(@installer).install_from_file_system(anything)
        dont_allow(@installer).download_from_hash(anything)
        mock(@installer).print_usage_and_abort(/parameter/)
        @installer.install '--file'
      end
    end
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
        archive = 'tarfile.tar'
        FileUtils.touch archive
        mock(@installer).install_from_archive archive
        @installer.install_from_file_system archive
      end

      it 'should print an error message and exit if the archive cannot be found' do
        mock(Railsthemes::Safe).log_and_abort(/Cannot find/)
        @installer.install_from_file_system 'tarfile.tar'
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
      stub(@installer).generate_tmpdir { 'tmp' }
      mock(@installer).install_from_file_system 'tmp'
      mock(@installer).untar_string('filepath', anything) { 'untar string' }
      mock(Railsthemes::Safe).system_call('untar string')
      @installer.install_from_archive 'filepath'
    end
  end

  describe :untar_string do
    it 'should return correct value for *.tar.gz file' do
      result = @installer.untar_string 'file.tar.gz', 'newdirpath'
      result.should == 'tar -zxf file.tar.gz --strip 1'
    end

    it 'should return correct value for *.tar file' do
      result = @installer.untar_string 'file.tar', 'newdirpath'
      result.should == 'tar -xf file.tar --strip 1'
    end
  end

  describe :archive? do
    it 'should be true for tar file' do
      @installer.archive?('test/a/b/c/d.tar').should be_true
    end

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
      stub(@installer).ensure_in_rails_root
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
      @installer.install '--file', filename
      verify_end_to_end_operation
    end

    #it 'should extract correctly from archive file' do
    #  filename = 'spec/fixtures/blank-assets.tar'
    #  stubby /\/tmp/
    #  @installer.install '--file', filename
    #  print_directory('/tmp')
    #  verify_end_to_end_operation
    #end

    #it 'should extract correctly from zipped archive file' do
    #  filename = 'spec/fixtures/blank-assets.tar.gz'
    #  stubby /\/tmp/
    #  @installer.install '--file', filename
    #  print_directory('/tmp')
    #  verify_end_to_end_operation
    #end
  end

  describe :download_from_hash

end

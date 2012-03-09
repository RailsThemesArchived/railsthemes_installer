require 'spec_helper'
require 'logger'

describe Railsthemes do
  before do
    @logger = Logger.new(File.join Dir.tmpdir, 'railsthemes.log')
    @installer = Railsthemes::Installer.new @logger
  end

  describe :execute do

    #Railsthemes.install '--file'

  end

  describe :install do
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
        stub(@installer).post_copying_changes

        mock(@installer).copy_with_replacement('filepath', /a$/)
        mock(@installer).copy_with_replacement('filepath', /b$/)
        @installer.install_from_file_system('filepath')
      end
    end

    context 'when the filepath is an archive file' do
      it 'should extract the archive file to a temp directory' do
        stub(@installer).post_copying_changes
        mock(@installer).tmpdir { 'tmpdir' }
        mock(Railsthemes::Safe).system_call 'tar -xf tarfile.tar -C tmpdir'
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

  describe :untar_string do
    it 'should return correct value for *.tar.gz file' do
      result = @installer.untar_string 'file.tar.gz', 'newdirpath'
      result.should == 'tar -zxf file.tar.gz -C newdirpath'
    end

    it 'should return correct value for *.tar file' do
      result = @installer.untar_string 'file.tar', 'newdirpath'
      result.should == 'tar -xf file.tar -C newdirpath'
    end
  end

  describe :download_from_hash

  describe :copy_with_replacement do
    before do
      FileUtils.mkdir 'fp'
      FileUtils.touch 'fp/file'
    end

    context 'when the destination file does not exist' do
      it 'should copy the file to the local directory' do
        @installer.copy_with_replacement 'fp', 'file'
        File.exists?('file').should == true
      end
    end

    context 'when the destination file exists' do
      before do
        FileUtils.touch 'file'
      end

      it 'should make a backup of existing file if it is present' do
        @installer.copy_with_replacement 'fp', 'file'
        File.exists?('file').should == true
        File.exists?('file.old').should == true
      end
    end
  end
end

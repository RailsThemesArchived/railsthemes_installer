require 'spec_helper'

describe Railsthemes do
  describe :execute do
    Railsthemes.install '--file'
  end

  describe :install do
    context 'when --file is given as a parameter' do
      it 'should read from the file argument' do
        mock(Railsthemes).install_from_file_system('filepath')
        Railsthemes.install '--file', 'filepath'
      end

      it 'should print usage and error message and exit if filepath is nil' do
        dont_allow(Railsthemes).install_from_file_system(anything)
        dont_allow(Railsthemes).download_from_hash(anything)
        mock(Railsthemes).print_usage_and_abort(/parameter/)
        Railsthemes.install '--file'
      end
    end

    context 'hash given' do
      it 'should pass the hash to the hash reading argument' do
        mock(Railsthemes).download_from_hash('hash')
        Railsthemes.install 'hash'
      end
    end

    context '--help given' do
      it 'should print the usage' do
        mock(Railsthemes).print_usage
        Railsthemes.install '--help'
      end
    end

    context 'when no parameters given' do
      it 'should print usage and error message and exit' do
        dont_allow(Railsthemes).install_from_file_system(anything)
        dont_allow(Railsthemes).download_from_hash(anything)
        mock(Railsthemes).print_usage_and_abort(/parameter/)
        Railsthemes.install '--file'
      end
    end
  end

  describe :install_from_file_system do
    context 'when the filepath is a directory' do
      before do
        mock(Railsthemes::Safe).directory?('filepath') { true }
      end

      it 'should skip any . or .. entries' do
        mock(Railsthemes::Safe).directory_entries_for('filepath') { ['.', '..'] }
        dont_allow(Railsthemes).copy_with_replacement(anything)
        Railsthemes.install_from_file_system('filepath')
      end

      it 'should copy the files from that directory into the Rails app' do
        mock(Railsthemes::Safe).directory_entries_for('filepath') { ['a', 'b'] }
        mock(Railsthemes).copy_with_replacement('filepath', 'a')
        mock(Railsthemes).copy_with_replacement('filepath', 'b')
        Railsthemes.install_from_file_system('filepath')
      end
    end

    context 'when the filepath is an archive file' do
      before do
        mock(Railsthemes::Safe).directory?('tarfile.tar') { false }
        stub(Railsthemes::Safe).directory?('tmpdir') { true }
        stub(Railsthemes::Safe).directory_entries_for('tmpdir') { [] }
      end

      it 'should extract the archive file to a temp directory' do
        mock(Railsthemes).tmpdir { 'tmpdir' }
        mock(Railsthemes::Safe).make_directory('tmpdir')
        mock(Railsthemes::Safe).system_call 'tar -xf tarfile.tar -C tmpdir'
        # not sure of a good way to test this
        #mock(Railsthemes).install_from_file_system('tmpdir')
        mock(Railsthemes::Safe).remove_directory 'tmpdir'
        Railsthemes.install_from_file_system 'tarfile.tar'
      end
    end

    context 'otherwise' do
      it 'should print usage and report an error reading the file' do
        mock(Railsthemes::Safe).directory?(anything) { false }
        mock(Railsthemes).archive?(anything) { false }
        mock(Railsthemes::Safe).print_usage_and_abort(/either/)
        Railsthemes.install_from_file_system("does not exist")
      end
    end
  end

  describe :untar_string do
    it 'should return correct value for *.tar.gz file' do
      result = Railsthemes.untar_string 'file.tar.gz', 'newdirpath'
      result.should == 'tar -zxf file.tar.gz -C newdirpath'
    end

    it 'should return correct value for *.tar file' do
      result = Railsthemes.untar_string 'file.tar', 'newdirpath'
      result.should == 'tar -xf file.tar -C newdirpath'
    end
  end

  describe :download_from_hash

  describe :copy_with_replacement do
    context 'when the destination file does not exist' do
      before do
        stub(Railsthemes::Safe).file_exists?('file') { false }
      end

      it 'should copy the file to the local directory' do
        mock(Railsthemes::Safe).copy_file_with_force('fp/file', 'file')
        Railsthemes.copy_with_replacement 'fp', 'file'
      end
    end

    context 'when the destination file exists' do
      before do
        stub(Railsthemes::Safe).file_exists?('file') { true }
      end

      it 'should make a backup of existing file if it is present' do
        mock(Railsthemes::Safe).rename_file('file', 'file.old')
        mock(Railsthemes::Safe).copy_file_with_force('fp/file', 'file')
        Railsthemes.copy_with_replacement 'fp', 'file'
      end
    end
  end
end

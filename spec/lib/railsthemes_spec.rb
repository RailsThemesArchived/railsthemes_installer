require 'spec_helper'

describe Railsthemes do
  describe :install do
    context 'when --file is given as a parameter' do
      it 'should read from the file argument' do
        mock(Railsthemes).read_from_file_system('filepath')
        Railsthemes.install '--file', 'filepath'
      end

      it 'should print error message and exit if filepath is nil' do
        dont_allow(Railsthemes).read_from_file_system(anything)
        dont_allow(Railsthemes).download_from_hash(anything)
        stub(Railsthemes).log_and_abort(/parameter/)
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

    context 'when nothing given' do
      it 'should print error message and exit' do
        dont_allow(Railsthemes).read_from_file_system(anything)
        dont_allow(Railsthemes).download_from_hash(anything)
        stub(Railsthemes).log_and_abort(/parameter/)
        Railsthemes.install '--file'
      end
    end
  end

  describe :read_from_file_system do
    context 'when the filepath is a directory' do
      before do
        mock(File).directory?('filepath') { true }
      end

      it 'should skip any . or .. entries' do
        mock(Dir).entries('filepath') { ['.', '..'] }
        dont_allow(Railsthemes).copy_with_replacement(anything)
        Railsthemes.read_from_file_system('filepath')
      end

      it 'should copy the files from that directory into the Rails app' do
        mock(Dir).entries('filepath') { ['a', 'b'] }
        mock(Railsthemes).copy_with_replacement('filepath', 'a')
        mock(Railsthemes).copy_with_replacement('filepath', 'b')
        Railsthemes.read_from_file_system('filepath')
      end
    end

    context 'when the filepath is a zip file' do
      it 'should extract the zip file to a temp directory'
    end

    context 'otherwise' do
      it 'should report an error reading the file'
    end
  end

  describe :download_from_hash

  describe :copy_with_replacement do
    context 'when the destination file does not exist' do
      before do
        stub(File).exists?('file') { false }
      end

      it 'should copy the file to the local directory' do
        mock(FileUtils).cp('fp/file', 'file', :force)
        Railsthemes.copy_with_replacement 'fp', 'file'
      end
    end

    context 'when the destination file exists' do
      before do
        stub(File).exists?('file') { true }
      end

      it 'should make a backup of existing file if it is present' do
        mock(FileUtils).cp('file', 'file.old')
        mock(FileUtils).cp('fp/file', 'file', :force)
        Railsthemes.copy_with_replacement 'fp', 'file'
      end
    end
  end
end

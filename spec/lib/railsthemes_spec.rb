require 'spec_helper'

describe Railsthemes do
  describe :install do
    context 'when --file is given as a parameter' do
      it 'should read from the file argument' do
        mock(Railsthemes).read_from_file('filepath')
        Railsthemes.install '--file', 'filepath'
      end

      it 'should print error message and exit if filepath is nil' do
        dont_allow(Railsthemes).read_from_file(anything)
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

    context 'when nothing given' do
      it 'should print error message and exit' do
        dont_allow(Railsthemes).read_from_file(anything)
        dont_allow(Railsthemes).download_from_hash(anything)
        stub(Railsthemes).log_and_abort(/parameter/)
        Railsthemes.install '--file'
      end
    end
  end

  describe :read_from_file

  describe :download_from_hash
end

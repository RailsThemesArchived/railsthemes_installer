require 'spec_helper'

describe Railsthemes do
  describe :install do
    context 'when --file is given as a parameter' do
      it 'should read from the file argument' do
        mock(Railsthemes).read_from_file('filepath')
        Railsthemes.install '--file', 'filepath'
      end

      it 'should exit if filepath is nil' do
        dont_allow(Railsthemes).read_from_file(anything)
        dont_allow(Railsthemes).download_from_hash(anything)
        stub(Railsthemes).log_and_abort(/parameter/)
        Railsthemes.install '--file'
      end
    end

    context 'otherwise' do
      it 'should otherwise just pass in the hash to the hash reading argument' do
        mock(Railsthemes).download_from_hash('hash')
        Railsthemes.install 'hash'
      end
    end
  end

  describe :read_from_file

  describe :download_from_hash
end

require 'spec_helper'

describe Railsthemes do
  describe :install do
    it 'should take --file as a parameter and read from the file argument' do
      mock(Railsthemes).read_from_file('filepath')
      Railsthemes.install '--file', 'filepath'
    end

    it 'should otherwise just pass in the hash to the hash reading argument' do
      mock(Railsthemes).download_from_hash('hash')
      Railsthemes.install 'hash'
    end
  end

  describe :read_from_file

  describe :download_from_hash
end

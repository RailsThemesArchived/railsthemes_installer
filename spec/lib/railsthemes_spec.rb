require 'spec_helper'

describe Railsthemes do
  describe :install do
    it 'should take --file as a parameter and read from the file argument' do
      mock(Railsthemes).read_from_file('abc')
      Railsthemes.install '--file', 'abc'
    end
  end

  describe :read_from_file do
  end
end

require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Utils do
  describe :archive? do
    it 'should be true for tar.gz file' do
      Railsthemes::Utils.archive?('test/a/b/c/d.tar.gz').should be_true
    end

    it 'should be false for other extensions' do
      Railsthemes::Utils.archive?('test/a/b/c.tar/d.zip').should be_false
    end
  end
end

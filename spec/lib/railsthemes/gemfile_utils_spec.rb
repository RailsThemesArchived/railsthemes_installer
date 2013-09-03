require 'spec_helper'

GemfileUtils = Railsthemes::GemfileUtils

describe GemfileUtils do
  describe '#rails_version' do
    it 'should return the right version' do
      gemfile = using_gem_specs :rails => '3.0.1'
      GemfileUtils.rails_version(gemfile).version.should == '3.0.1'
    end

    it 'should return nil if there is no rails present' do
      gemfile = using_gem_specs
      GemfileUtils.rails_version(gemfile).should be_nil
    end
  end
end

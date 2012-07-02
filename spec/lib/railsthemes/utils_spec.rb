require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Utils do
  before do
    setup_logger
  end

  describe :archive? do
    it 'should be true for tar.gz file' do
      Railsthemes::Utils.archive?('test/a/b/c/d.tar.gz').should be_true
    end

    it 'should be false for other extensions' do
      Railsthemes::Utils.archive?('test/a/b/c.tar/d.zip').should be_false
    end
  end

  describe '#get_primary_configuration' do
    it 'should give erb and css when there is no Gemfile' do
      Railsthemes::Utils.get_primary_configuration('').should == ['erb', 'css']
    end

    it 'should give haml,scss when haml and sass are in the Gemfile' do
      gemfile = using_gems 'haml', 'sass'
      Railsthemes::Utils.get_primary_configuration(gemfile).should == ['haml', 'scss']
    end

    it 'should give haml,css when sass is not in the Gemfile but haml is' do
      gemfile = using_gems 'haml'
      Railsthemes::Utils.get_primary_configuration(gemfile).should == ['haml', 'css']
    end

    it 'should give erb,scss when haml is not in the gemfile but sass is' do
      gemfile = using_gems 'sass'
      Railsthemes::Utils.get_primary_configuration(gemfile).should == ['erb', 'scss']
    end

    it 'should give erb,css when haml and sass are not in the gemfile' do
      gemfile = using_gems
      Railsthemes::Utils.get_primary_configuration(gemfile).should == ['erb', 'css']
    end
  end

  describe 'download' do
    it 'should log and abort if file not found at url' do
      FakeWeb.register_uri :get,
        'http://example.com/something',
        :body => 'some random stuff', :status => ['404', 'Not Found']
      mock(Railsthemes::Safe).log_and_abort /trouble/
      Railsthemes::Utils.download(:url => 'http://example.com/something', :save_to => 'whatever')
    end
  end
end

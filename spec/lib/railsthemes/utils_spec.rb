require 'spec_helper'

describe Railsthemes::Utils do
  describe :archive? do
    it 'should be false if the file does not exist' do
      Railsthemes::Utils.archive?('test/a/b/c/d.tar.gz').should be_false
    end

    it 'should be true for tar.gz file' do
      FileUtils.mkdir_p('test/a/b/c')
      FileUtils.touch('test/a/b/c/d.tar.gz')
      Railsthemes::Utils.archive?('test/a/b/c/d.tar.gz').should be_true
    end

    it 'should be false for other extensions' do
      FileUtils.mkdir_p('test/a/b/c.tar')
      FileUtils.touch('test/a/b/c.tar/d.zip')
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

  describe 'add_gem_to_gemfile' do
    it 'should add the gem to the Gemfile' do
      Railsthemes::Utils.add_gem_to_gemfile 'test'
      Railsthemes::Utils.add_gem_to_gemfile 'test2'
      lines = File.open('Gemfile').readlines.map(&:strip)
      lines.count.should == 2
      lines[0].should =~ /^gem 'test'/
      lines[1].should =~ /^gem 'test2'/
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

  describe '.set_layout_in_application_controller' do
    before do
      @base = <<-EOS
class ApplicationController < ActionController::Base
  protect_from_forgery
      EOS
    end

    it 'should add the layout line if it does not exist' do
      create_file 'app/controllers/application_controller.rb', :content => "#{@base}\nend"
      Railsthemes::Utils.set_layout_in_application_controller('magenta')
      lines = File.read('app/controllers/application_controller.rb').split("\n")
      lines.grep(/layout 'railsthemes_magenta'/).count.should == 1
    end

    it 'should modify the layout line if it exists but different' do
      create_file 'app/controllers/application_controller.rb', :content => <<-EOS
#{@base}
  layout 'railsthemes_orange'
end
      EOS
      Railsthemes::Utils.set_layout_in_application_controller('magenta')
      lines = File.read('app/controllers/application_controller.rb').split("\n")
      lines.grep(/layout 'railsthemes_orange'/).count.should == 0
      lines.grep(/layout 'railsthemes_magenta'/).count.should == 1
    end

    it 'should not modify the layout line if it exists and same' do
      create_file 'app/controllers/application_controller.rb', :content => <<-EOS
#{@base}
  layout 'railsthemes_orange'
end
      EOS
      Railsthemes::Utils.set_layout_in_application_controller('orange')
      lines = File.read('app/controllers/application_controller.rb').split("\n")
      lines.grep(/layout 'railsthemes_orange'/).count.should == 1
    end
  end

end

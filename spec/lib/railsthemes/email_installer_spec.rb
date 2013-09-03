require 'spec_helper'

describe Railsthemes::EmailInstaller do
  before do
    @installer = Railsthemes::EmailInstaller.new
    @tempdir = stub_tempdir
  end

  describe '#install_from_file_system' do
    it 'should not install and return false if the theme does not have any mailers' do
      pending
    end

    it 'should install and return true if the theme does not have any mailers' do
      pending
    end
  end

  describe '#install_mail_gems_if_necessary' do
    it 'should install no new gems if premailer-rails gem already installed' do
      write_gemfiles_using_gems 'premailer-rails', 'hpricot'
      dont_allow(Railsthemes::Utils).add_gem_to_gemfile(anything)
      @installer.install_mail_gems_if_necessary
    end

    it 'when nokogiri already installed, should install the pr gem' do
      write_gemfiles_using_gems 'nokogiri'
      mock(Railsthemes::Utils).add_gem_to_gemfile('premailer-rails')
      @installer.install_mail_gems_if_necessary
    end

    it 'when hpricot already installed, should install the pr gem only' do
      write_gemfiles_using_gems 'hpricot'
      mock(Railsthemes::Utils).add_gem_to_gemfile('premailer-rails')
      @installer.install_mail_gems_if_necessary
    end

    it 'when no xml gem or pr installed, should install the pr gem and hpricot' do
      FileUtils.touch('Gemfile.lock')
      mock(Railsthemes::Utils).add_gem_to_gemfile('hpricot')
      mock(Railsthemes::Utils).add_gem_to_gemfile('premailer-rails')
      @installer.install_mail_gems_if_necessary
    end
  end

  describe '#add_to_asset_precompilation_list' do
    before do
      create_file 'app/assets/stylesheets/railsthemes/1_email.css.erb'
      create_file 'app/assets/stylesheets/railsthemes/2_email.css.erb'
    end

    it 'should add it to the list if the line is not there yet' do
      create_file 'config/environments/production.rb', :content => <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
end
      EOS
      @installer.add_to_asset_precompilation_list
      File.read('config/environments/production.rb').should == <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( railsthemes/1_email.css railsthemes/2_email.css )
end
EOS
    end

    it 'should update the line if the line is there already' do
      create_file 'config/environments/production.rb', :content => <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( railsthemes_magenta.js railsthemes_magenta.css )
  config.assets.precompile += %w( railsthemes/1_email.css )
end
      EOS
      @installer.add_to_asset_precompilation_list
      File.read('config/environments/production.rb').should == <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( railsthemes_magenta.js railsthemes_magenta.css )
  config.assets.precompile += %w( railsthemes/1_email.css railsthemes/2_email.css )
end
EOS
    end

    it 'should add it to the list if there is a different theme already installed' do
      create_file 'config/environments/production.rb', :content => <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( railsthemes_orange/email1.css )
end
      EOS
      @installer.add_to_asset_precompilation_list
    end
  end
end

require 'spec_helper'
require 'railsthemes'

describe Railsthemes::EmailInstaller do
  before do
    setup_logger
    @installer = Railsthemes::EmailInstaller.new
    @tempdir = stub_tempdir
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
end

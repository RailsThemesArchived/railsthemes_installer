require 'spec_helper'
require 'railsthemes'

describe Railsthemes::EmailInstaller do
  before do
    setup_logger
    @installer = Railsthemes::EmailInstaller.new
    @tempdir = stub_tempdir
  end

  describe '#install_mail_gems_if_necessary' do
    it 'should install no new gems if premailer-rails3 gem already installed' do
      write_gemfiles_using_gems 'premailer-rails3', 'hpricot'
      dont_allow(Railsthemes::Utils).add_gem_to_gemfile(anything)
      dont_allow(Railsthemes::Safe).system_call('bundle')
      @installer.install_mail_gems_if_necessary
    end

    it 'when nokogiri already installed, should install the pr3 gem' do
      write_gemfiles_using_gems 'nokogiri'
      mock(Railsthemes::Utils).add_gem_to_gemfile('premailer-rails3')
      mock(Railsthemes::Safe).system_call('bundle')
      @installer.install_mail_gems_if_necessary
    end

    it 'when hpricot already installed, should install the pr3 gem only' do
      write_gemfiles_using_gems 'hpricot'
      mock(Railsthemes::Utils).add_gem_to_gemfile('premailer-rails3')
      mock(Railsthemes::Safe).system_call('bundle')
      @installer.install_mail_gems_if_necessary
    end

    it 'when no xml gem or pr3 installed, should install the pr3 gem and hpricot' do
      FileUtils.touch('Gemfile.lock')
      mock(Railsthemes::Utils).add_gem_to_gemfile('hpricot')
      mock(Railsthemes::Utils).add_gem_to_gemfile('premailer-rails3')
      mock(Railsthemes::Safe).system_call('bundle')
      @installer.install_mail_gems_if_necessary
    end
  end
end

require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Switcher do
  before do
    setup_logger
    @switcher = Railsthemes::Switcher.new
    @tempdir = stub_tempdir
  end

  describe '#list' do
    context 'no themes are available' do
      it 'should output no themes available' do
        mock(@switcher).installed_themes { [] }
        mock(Railsthemes::Logging.logger).warn 'There are currently no RailsThemes themes installed.'
        @switcher.list
      end
    end

    context 'themes are available' do
      it 'should output the themes' do
        mock(@switcher).installed_themes { ['theme1', 'theme2'] }
        mock(Railsthemes::Logging.logger).warn 'RailsThemes themes currently installed:'
        mock(Railsthemes::Logging.logger).warn ' - theme1'
        mock(Railsthemes::Logging.logger).warn ' - theme2'
        @switcher.list
      end
    end
  end

  describe '#switch_to' do
  end

  describe '#installed_themes' do
    context 'there are no themes installed' do
      it 'should show nothing installed ' do
        @switcher.installed_themes.should == []
      end
    end

    context 'one theme installed' do
      before do
        create_file('app/assets/stylesheets/railsthemes_theme1.css')
        create_file('app/assets/stylesheets/railsthemes_theme1/something.css')
      end

      it 'should show the theme installed' do
        @switcher.installed_themes.should == ['theme1']
      end
    end

    context 'many themes installed' do
      before do
        create_file('app/assets/stylesheets/railsthemes_theme1.css')
        create_file('app/assets/stylesheets/railsthemes_theme1/something.css')
        create_file('app/assets/stylesheets/railsthemes_theme2.css')
        create_file('app/assets/stylesheets/railsthemes_theme2/something.css')
      end

      it 'should show the installed themes' do
        @switcher.installed_themes.should == ['theme1', 'theme2']
      end
    end
  end

end

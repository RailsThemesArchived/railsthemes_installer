require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Switcher do
  before do
    setup_logger
    @switcher = Railsthemes::Switcher.new
    @tempdir = stub_tempdir
  end

  describe '.list' do
    context 'there are no themes installed' do
      it 'should show nothing installed ' do
        mock(Railsthemes::Logging.logger).warn 'There are currently no RailsThemes themes installed.'
        @switcher.list
      end
    end

    context 'one theme installed' do
      before do
        create_file('app/assets/stylesheets/railsthemes_themename.css')
        create_file('app/assets/stylesheets/railsthemes_themename/something.css')
      end

      it 'should show the theme installed' do
        mock(Railsthemes::Logging.logger).warn 'RailsThemes themes currently installed:'
        mock(Railsthemes::Logging.logger).warn ' - themename'
        @switcher.list
      end
    end

    context 'many themes installed' do
      before do
        create_file('app/assets/stylesheets/railsthemes_themename.css')
        create_file('app/assets/stylesheets/railsthemes_themename/something.css')
        create_file('app/assets/stylesheets/railsthemes_themename2.css')
        create_file('app/assets/stylesheets/railsthemes_themename2/something.css')
      end

      it 'should show the installed themes' do
        mock(Railsthemes::Logging.logger).warn 'RailsThemes themes currently installed:'
        mock(Railsthemes::Logging.logger).warn ' - themename'
        mock(Railsthemes::Logging.logger).warn ' - themename2'
        @switcher.list
      end
    end
  end
end

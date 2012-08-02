require 'spec_helper'
require 'railsthemes'
require 'json'

describe Railsthemes::ThemeInstaller do
  before do
    setup_logger
    @installer = Railsthemes::ThemeInstaller.new
    @tempdir = stub_tempdir

    # would be interesting to see if we still need these
    FileUtils.touch('Gemfile.lock')
  end

  describe :install_from_archive do
    # does not work on Windows, NotImplementedError in tar module
    it 'should extract and then install from that extracted directory' do
      filename = 'spec/fixtures/blank-assets-archived/erb-css.tar.gz'
      FakeFS::FileSystem.clone(filename)
      mock(@installer).install_from_file_system @tempdir
      @installer.install_from_archive filename
    end
  end

  describe :install_from_file_system do
    context 'when the filepath is a directory' do
      it 'should copy the files from that directory into the Rails app' do
        FileUtils.mkdir_p('filepath/base')
        FileUtils.touch('filepath/base/a')
        FileUtils.touch('filepath/base/b')
        mock(@installer).post_copying_changes

        @installer.install_from_file_system('filepath')
        File.should exist('a')
        File.should exist('b')
      end

      it 'should handle directories that have spaces' do
        FileUtils.mkdir_p('file path/base')
        FileUtils.touch('file path/base/a')
        FileUtils.touch('file path/base/b')
        mock(@installer).post_copying_changes

        @installer.install_from_file_system('file path')
        File.should exist('a')
        File.should exist('b')
      end

      it 'should handle windows style paths' do
        FileUtils.mkdir_p('fp1/fp2/base')
        FileUtils.touch('fp1/fp2/base/a')
        FileUtils.touch('fp1/fp2/base/b')
        FileUtils.mkdir_p('fp1/fp2/gems')
        mock(@installer).post_copying_changes

        @installer.install_from_file_system('fp1\fp2')
        File.should exist('a')
        File.should exist('b')
      end

      it 'should not copy system files' do
        FileUtils.mkdir_p('filepath/base')
        FileUtils.touch('filepath/base/.DS_Store')
        mock(@installer).post_copying_changes

        @installer.install_from_file_system('filepath')
        File.should_not exist('.DS_Store')
      end
    end

    describe 'override file behavior' do
      before do
        FileUtils.mkdir_p('filepath/gems')
        FileUtils.mkdir_p('filepath/base/app/assets/stylesheets')
        FileUtils.mkdir_p("app/assets/stylesheets")
        @filename = 'app/assets/stylesheets/overrides.css.scss'
        FileUtils.touch("filepath/base/#{@filename}")
        mock(@installer).post_copying_changes
        stub(@installer).popup_documentation
      end

      it 'should not overwrite override files when they already exist' do
        File.open(@filename, 'w') do |f|
          f.write "existing override"
        end

        @installer.install_from_file_system('filepath')
        File.should exist(@filename)
        File.read(@filename).should =~ /existing override/
      end

      it 'should create override files when they do not already exist' do
        @installer.install_from_file_system('filepath')
        File.should exist(@filename)
        File.read(@filename).should == ''
      end
    end

    context 'when the filepath is an archive file' do
      it 'should extract the archive file to a temp directory if the archive exists' do
        archive = 'tarfile.tar.gz'
        FileUtils.touch archive
        mock(@installer).install_from_archive archive
        @installer.install_from_file_system 'tarfile'
      end
    end

    context 'otherwise' do
      it 'should report an error reading the file' do
        mock(Railsthemes::Safe).log_and_abort(/either/)
        @installer.install_from_file_system("does not exist")
      end
    end
  end

  describe '#create_railsthemes_demo_pages' do
    before do
      FileUtils.mkdir('config')
      File.open(File.join('config', 'routes.rb'), 'w') do |f|
        f.write <<-EOS
RailsApp::Application.routes.draw do
  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
        EOS
      end
    end

    it 'should create a RailsThemes controller' do
      @installer.create_railsthemes_demo_pages
      controller = File.join('app', 'controllers', 'railsthemes_controller.rb')
      lines = File.read(controller).split("\n")
      lines.count.should == 11
      lines.first.should match /class RailsthemesController < ApplicationController/
    end

    it 'should insert lines into the routes file' do
      @installer.create_railsthemes_demo_pages
      routes_file = File.join('config', 'routes.rb')
      lines = File.read(routes_file).split("\n")
      lines.grep(/match 'railsthemes\/landing' => 'railsthemes#landing'/).count.should == 1
      lines.grep(/match 'railsthemes\/inner' => 'railsthemes#inner'/).count.should == 1
      lines.grep(/match 'railsthemes\/jquery_ui' => 'railsthemes#jquery_ui'/).count.should == 1
    end

    it 'should not insert lines into the routes file when run more than once' do
      @installer.create_railsthemes_demo_pages
      @installer.create_railsthemes_demo_pages
      routes_file = File.join('config', 'routes.rb')
      lines = File.read(routes_file).split("\n")
      lines.grep(/match 'railsthemes\/landing' => 'railsthemes#landing'/).count.should == 1
      lines.grep(/match 'railsthemes\/inner' => 'railsthemes#inner'/).count.should == 1
      lines.grep(/match 'railsthemes\/jquery_ui' => 'railsthemes#jquery_ui'/).count.should == 1
    end
  end

  describe :install_gems_from do
    it 'should install the gems that we specify that match' do
      FakeFS::FileSystem.clone('spec/fixtures/blank-assets')
      # we only know about formtastic and simple_form in the gems directory
      @installer.install_gems_from("spec/fixtures/blank-assets/erb-css", ['formtastic', 'kaminari'])
      File.should exist('app/assets/stylesheets/formtastic.css.scss')
      File.should_not exist('app/assets/stylesheets/kaminari.css.scss')
      File.should_not exist('app/assets/stylesheets/simple_form.css.scss')
    end
  end

  describe 'end to end operation' do
    def verify_end_to_end_operation
      ['app/assets/images/image1.png',
       'app/assets/images/bg/sprite.png',
       'app/assets/javascripts/jquery.dataTables.js',
       'app/assets/javascripts/scripts.js.erb',
       'app/assets/stylesheets/style.css.erb',
       'app/views/layouts/_interior_sidebar.html.erb',
       'app/views/layouts/application.html.erb',
       'app/views/layouts/homepage.html.erb'].each do |filename|
         File.should exist(filename), "#{filename} was not present"
      end
      File.open('app/assets/stylesheets/style.css.erb').each do |line|
        line.should match /style.css.erb/
      end
    end

    before do
      stub(@installer).post_copying_changes
      FakeFS::FileSystem.clone('spec/fixtures')
      # should add some gems to the gemfile here and test gem installation
    end

    it 'should extract correctly from directory' do
      filename = 'spec/fixtures/blank-assets/erb-css'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end

    # does not work on Windows, NotImplementedError in tar module
    it 'should extract correctly from archive' do
      filename = 'spec/fixtures/blank-assets-archived/erb-css'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end
  end

end

require 'spec_helper'
require 'railsthemes'

describe Railsthemes::ThemeInstaller do
  before do
    setup_logger
    @installer = Railsthemes::ThemeInstaller.new
    @tempdir = stub_tempdir
    FileUtils.touch('Gemfile.lock')
  end

  describe '#install_from_server' do
    context 'when a gemfile.lock is present' do
      before do
        mock(@installer).send_gemfile('panozzaj@gmail.com:code')
      end

      it 'should download the file correctly when valid configuration' do
        FakeWeb.register_uri :get,
          /download\?code=panozzaj@gmail.com:code&config=haml,scss/,
          :body => 'auth_url'
        mock(@installer).get_primary_configuration('') { 'haml,scss' }
        mock(Railsthemes::Utils).download_file_to('auth_url', "#{@tempdir}/archive.tar.gz")
        mock(@installer).install_from_archive "#{@tempdir}/archive.tar.gz"
        @installer.install_from_server 'panozzaj@gmail.com:code'
      end

      it 'should fail with an error message on any error message' do
        FakeWeb.register_uri :get,
          'https://railsthemes.com/download?code=panozzaj@gmail.com:code&config=',
          :body => '', :status => ['401', 'Unauthorized']
        mock(@installer).get_primary_configuration('') { '' }
        mock(Railsthemes::Safe).log_and_abort(/didn't recognize/)
        @installer.install_from_server 'panozzaj@gmail.com:code'
      end
    end
  end

  describe :install_from_archive do
    # does not work on Windows, NotImplementedError in tar module
    it 'should extract and then install from that extracted directory' do
      filename = 'spec/fixtures/blank-assets.tar.gz'
      FakeFS::FileSystem.clone(filename)
      mock(@installer).install_from_file_system @tempdir
      @installer.install_from_archive filename
    end
  end

  describe :send_gemfile do
    before do
      File.open('Gemfile.lock', 'w') do |file|
        file.puts "GEM\n  remote: https://rubygems.org/"
      end
    end

    it 'should hit the server with the Gemfile and return the results, arrayified' do
      FakeFS.deactivate! # has an issue with generating tmpfiles otherwise
      params = { :code => 'panozzaj@gmail.com:code', :gemfile_lock => File.new('Gemfile.lock', 'rb') }
      FakeWeb.register_uri :post, 'https://railsthemes.com/gemfiles/parse',
        :body => 'haml,scss', :parameters => params
      @installer.send_gemfile('panozzaj@gmail.com:code')
    end

    it 'should return a blank array when there are issues' do
      FakeFS.deactivate! # has an issue with generating tmpfiles otherwise
      FakeWeb.register_uri :post, 'https://railsthemes.com/gemfiles/parse',
        :body => '', :parameters => :any, :status => ['401', 'Unauthorized']
      @installer.send_gemfile('panozzaj@gmail.com:code')
    end
  end

  describe '#get_primary_configuration' do
    it 'should give erb,css when there is no Gemfile' do
      @installer.get_primary_configuration('').should == 'erb,css'
    end

    it 'should give haml,scss when haml and sass are in the Gemfile' do
      gemfile = using_gems 'haml', 'sass'
      @installer.get_primary_configuration(gemfile).should == 'haml,scss'
    end

    it 'should give haml,css when sass is not in the Gemfile but haml is' do
      gemfile = using_gems 'haml'
      @installer.get_primary_configuration(gemfile).should == 'haml,css'
    end

    it 'should give erb,scss when haml is not in the gemfile but sass is' do
      gemfile = using_gems 'sass'
      @installer.get_primary_configuration(gemfile).should == 'erb,scss'
    end

    it 'should give erb,css when haml and sass are not in the gemfile' do
      gemfile = using_gems
      @installer.get_primary_configuration(gemfile).should == 'erb,css'
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
        @filename = 'app/assets/stylesheets/railsthemes_THEME_overrides.anything'
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
        @installer.install_from_file_system archive
      end

      it 'should print an error message and exit if the archive cannot be found' do
        mock(Railsthemes::Safe).log_and_abort(/Cannot find/)
        @installer.install_from_file_system 'tarfile.tar.gz'
      end
    end

    context 'otherwise' do
      it 'should print usage and report an error reading the file' do
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
      @installer.install_gems_from("spec/fixtures/blank-assets", ['formtastic', 'kaminari'])
      File.should exist('app/assets/stylesheets/formtastic.css.scss')
      File.should_not exist('app/assets/stylesheets/kaminari.css.scss')
      File.should_not exist('app/assets/stylesheets/simple_form.css.scss')
    end
  end

end

require 'spec_helper'
require 'railsthemes'
require 'json'

describe Railsthemes::ThemeInstaller do
  def filesystem
    Dir["**/*"]
  end

  def create_file filename, opts = {}
    FileUtils.mkdir_p(File.dirname(filename))
    FileUtils.touch(filename)
    File.open(filename, 'w') { |f| f.write opts[:content] } if opts[:content]
  end

  def filesystem_should_match files_to_match
    (filesystem & files_to_match).should =~ files_to_match
  end

  before do
    setup_logger
    @installer = Railsthemes::ThemeInstaller.new
    @tempdir = stub_tempdir

    # would be interesting to see if we still need these
    FileUtils.touch('Gemfile.lock')
  end

  describe :install_from_archive do
    # this spec does not work on Windows, NotImplementedError in tar module
    it 'should extract and then install from that extracted directory' do
      filename = 'spec/fixtures/blank-assets-archived/tier1-erb-scss.tar.gz'
      FakeFS::FileSystem.clone(filename)
      mock(@installer).install_from_file_system @tempdir
      @installer.install_from_archive filename
    end
  end

  describe :install_from_file_system do
    context 'when the filepath is a directory' do
      context 'copying files' do
        it 'should copy controllers (and subdirectories, generally)' do
          create_file 'theme/controllers/controller1.rb'
          create_file 'theme/controllers/railsthemes_themename/controller2.rb'

          @installer.install_from_file_system('theme')

          filesystem_should_match [
            'app/controllers/controller1.rb',
            'app/controllers/railsthemes_themename/controller2.rb',
          ]
        end

        it 'should copy helpers' do
          create_file 'theme/helpers/helper1.rb'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/helpers/helper1.rb']
        end

        it 'should copy layouts' do
          create_file 'theme/layouts/layout1.html.haml'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/views/layouts/layout1.html.haml']
        end

        it 'should copy stylesheets' do
          create_file 'theme/stylesheets/stylesheet1.css.scss'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/assets/stylesheets/stylesheet1.css.scss']
        end

        it 'should copy javascripts' do
          create_file 'theme/javascripts/file1.js'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/assets/javascripts/file1.js']
        end

        it 'should copy docs' do
          create_file 'theme/doc/some_doc.md'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['doc/some_doc.md']
        end

        it 'should copy images' do
          create_file 'theme/images/image1.jpg'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/assets/images/image1.jpg']
        end

        it 'should copy mailers' do
          create_file 'theme/mailers/mailer.rb'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/mailers/mailer.rb']
        end
      end

      it 'should handle directories that have spaces' do
        create_file 'theme/images/image with spaces.png'
        @installer.install_from_file_system('theme')
        filesystem_should_match ['app/assets/images/image with spaces.png']
      end

      it 'should handle windows style paths' do
        create_file 'subdir/theme/images/image.png'
        @installer.install_from_file_system('subdir\theme')
        filesystem_should_match ['app/assets/images/image.png']
      end

      it 'should not copy system files' do
        create_file 'theme/controllers/.DS_Store'
        @installer.install_from_file_system('theme')
        File.should_not exist('app/controllers/.DS_Store')
      end

      it 'should do the post copying changes needed' do
        create_file 'theme/theme_name', :content => 'themename'
        mock(@installer).post_copying_changes('themename')
        @installer.install_from_file_system('theme')
      end
    end

    describe 'override file behavior' do
      before do
        create_file 'theme/stylesheets/overrides.css.scss', :content => 'the override'
        @filename = 'app/assets/stylesheets/overrides.css.scss'
      end

      it 'should not overwrite override files when they already exist' do
        create_file @filename, :content => 'do not replace'
        @installer.install_from_file_system('theme')
        File.should exist(@filename)
        File.read(@filename).should =~ /do not replace/
      end

      it 'should create override files when they do not already exist' do
        @installer.install_from_file_system('theme')
        File.should exist(@filename)
        File.read(@filename).should == 'the override'
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

  # this should arguably be an integration test, but I'm not sure how
  # fakefs + running arbitrary binaries will work out
  describe 'end to end behavior' do
    before do
      stub(@installer).post_copying_changes
      FakeFS::FileSystem.clone('spec/fixtures')
    end

    def verify_end_to_end_operation
      [
       'app/controllers/controller1.rb',
       'doc/some_doc.md',
       'app/helpers/helper1.rb',
       'app/assets/images/image1.jpg',
       'app/assets/javascripts/file1.js',
       'app/views/layouts/layout1.html.haml',
       'app/mailers/mailer.rb',
       'app/assets/stylesheets/stylesheet1.css.scss',
      ].each do |filename|
        File.should exist(filename), "#{filename} was expected but not present"
      end
    end

    it 'should extract correctly from directory' do
      filename = 'spec/fixtures/blank-assets/tier1-erb-scss'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end

    # this spec does not work on Windows, NotImplementedError in tar module
    it 'should extract correctly from archive' do
      filename = 'spec/fixtures/blank-assets-archived/tier1-erb-scss'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end
  end

  describe '#post_copying_changes' do
    it 'should call the right submethods' do
      mock(@installer).remove_unwanted_public_files
      mock(@installer).create_railsthemes_demo_routes
      mock(@installer).add_needed_gems
      mock(@installer).set_layout_in_application_controller 'theme_name'
      @installer.post_copying_changes 'theme_name'
    end
  end

  describe '#remove_unwanted_public_files' do
    it 'should remove files we do not want hanging around' do
      files = [
        'public/index.html',
        'public/404.html',
        'public/422.html',
        'public/500.html',
      ]
      files.each do |filename|
        create_file filename
      end

      @installer.remove_unwanted_public_files

      files.each do |filename|
        File.should_not exist(filename), "#{filename} was expected to be gone, but it is still here"
      end
    end
  end

  describe '#add_needed_gems' do
    it 'should require sass, jquery-rails, jquery-ui-rails and foundation gems' do
      create_file 'Gemfile'
      @installer.add_needed_gems
      lines = File.read('Gemfile').split("\n")
      lines.grep("gem 'sass'").count.should == 1
      lines.grep("gem 'jquery-rails'").count.should == 1
      lines.grep("gem 'jquery-ui-rails'").count.should == 1
      lines.grep("gem 'foundation'").count.should == 1
    end

    it 'should not readd the gems if they are already present' do
      write_gemfiles_using_gems 'sass', 'jquery-rails', 'jquery-ui-rails', 'foundation'
      @installer.add_needed_gems
      lines = File.read('Gemfile').split("\n")
      lines.grep("gem 'sass'").count.should == 1
      lines.grep("gem 'jquery-rails'").count.should == 1
      lines.grep("gem 'jquery-ui-rails'").count.should == 1
      lines.grep("gem 'foundation'").count.should == 1
    end
  end

  describe '#create_railsthemes_demo_routes' do
    before do
      contents = <<-EOS
RailsApp::Application.routes.draw do
  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
      EOS
      create_file 'config/routes.rb', :content => contents
    end

    it 'should add routing if it has not been generated yet' do
      @installer.create_railsthemes_demo_routes
      File.read('config/routes.rb').split("\n").grep(
        /match 'railsthemes', :controller => :railsthemes, :action => :index/
      ).count.should == 1
    end

    it 'should not readd routing' do
      @installer.create_railsthemes_demo_routes
      @installer.create_railsthemes_demo_routes
      File.read('config/routes.rb').split("\n").grep(
        /match 'railsthemes', :controller => :railsthemes, :action => :index/
      ).count.should == 1
    end
  end

  describe '#set_layout_in_application_controller' do
    before do
      @base = <<-EOS
class ApplicationController < ActionController::Base
  protect_from_forgery
      EOS
    end

    it 'should add the layout line if it does not exist' do
      create_file 'app/controllers/application_controller.rb', :content => "#{@base}\nend"
      @installer.set_layout_in_application_controller('magenta')
      lines = File.read('app/controllers/application_controller.rb').split("\n")
      lines.grep(/layout 'railsthemes_magenta'/).count.should == 1
    end

    it 'should modify the layout line if it exists but different' do
      create_file 'app/controllers/application_controller.rb', :content => <<-EOS
#{@base}
  layout 'railsthemes_orange'
end
      EOS
      @installer.set_layout_in_application_controller('magenta')
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
      @installer.set_layout_in_application_controller('orange')
      lines = File.read('app/controllers/application_controller.rb').split("\n")
      lines.grep(/layout 'railsthemes_orange'/).count.should == 1
    end
  end
end

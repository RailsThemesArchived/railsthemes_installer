require 'spec_helper'
require 'json'

describe Railsthemes::ThemeInstaller do
  before do
    @installer = Railsthemes::ThemeInstaller.new
    @tempdir = stub_tempdir

    # would be interesting to see if we still need these
    FileUtils.touch('Gemfile.lock')
    stub(Railsthemes::GemfileUtils).rails_version.times(any_times) { '0' }
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

        it 'should copy views' do
          create_file 'theme/views/railsthemes_themename/view1.html.erb'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/views/railsthemes_themename/view1.html.erb']
        end

        it 'should copy fonts' do
          create_file 'theme/fonts/railsthemes_themename/myfont.ttf'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['app/assets/fonts/railsthemes_themename/myfont.ttf']
        end

        it 'should copy lib files' do
          create_file 'theme/lib/railsthemes/sass.rb'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['lib/railsthemes/sass.rb']
        end

        it 'should copy vendored stylesheets' do
          create_file 'theme/vendor/assets/stylesheets/coderay.css'
          @installer.install_from_file_system('theme')
          filesystem_should_match ['vendor/assets/stylesheets/coderay.css']
        end
      end

      it 'should handle directories that have spaces' do
        create_file 'theme/images/image with spaces.png'
        @installer.install_from_file_system('theme')
        filesystem_should_match ['app/assets/images/image with spaces.png']
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

    describe 'override stylesheet file behavior' do
      before do
        create_file 'theme/stylesheets/overrides.css.scss', :content => 'overridden'
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
        File.read(@filename).should == 'overridden'
      end
    end

    describe 'keep header navigation if it exists' do
      context 'erb' do
        before do
          basename = '_header_navigation.html.erb'
          create_file "theme/layouts/#{basename}", :content => 'overridden'
          @filename = "app/views/layouts/#{basename}"
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
          File.read(@filename).should == 'overridden'
        end
      end

      context 'haml' do
        before do
          basename = '_header_navigation.html.haml'
          create_file "theme/layouts/#{basename}", :content => 'overridden'
          @filename = "app/views/layouts/#{basename}"
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
          File.read(@filename).should == 'overridden'
        end
      end
    end

    context 'otherwise' do
      it 'should report an error reading the file' do
        mock(Railsthemes::Safe).log_and_abort(/Expected a directory/)
        @installer.install_from_file_system("does not exist")
      end
    end
  end

  describe '#post_copying_changes' do
    it 'should call the right submethods' do
      mock(@installer).remove_unwanted_public_files
      mock(@installer).create_railsthemes_demo_routes
      mock(@installer).add_needed_gems
      mock(Railsthemes::Utils).set_layout_in_application_controller 'theme_name'
      mock(@installer).add_to_asset_precompilation_list 'theme_name'
      mock(@installer).comment_out_formtastic_if_user_does_not_use_formtastic 'theme_name'
      mock(@installer).add_sass_module_line
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
    describe 'general gems' do
      context 'are not present' do
        it 'should require them' do
          create_file 'Gemfile'
          @installer.add_needed_gems
          lines = File.read('Gemfile').split("\n")
          lines.grep(/^gem 'sass'/).count.should == 1
          lines.grep(/^gem 'jquery-rails'/).count.should == 1
          lines.grep(/^gem 'jquery-ui-rails'/).count.should == 1
          lines.grep(/^gem 'coderay'/).count.should == 1
        end
      end

      context 'are present' do
        it 'should not readd them' do
          write_gemfiles_using_gems 'sass', 'jquery-rails', 'jquery-ui-rails', 'coderay'
          @installer.add_needed_gems
          lines = File.read('Gemfile').split("\n")
          lines.grep(/^gem 'sass'/).count.should == 1
          lines.grep(/^gem 'jquery-rails'/).count.should == 1
          lines.grep(/^gem 'jquery-ui-rails'/).count.should == 1
          lines.grep(/^gem 'coderay'/).count.should == 1
        end
      end
    end

    describe 'asset gems' do
      before do
        stub(Railsthemes::Utils).add_gem_to_gemfile
      end

      context 'Rails ~> 4.0.0 app' do
        before do
          stub(Railsthemes::GemfileUtils).rails_version { '4.0.0' }
        end

        describe 'compass-rails' do
          context 'gem is not present' do
            it 'should add it without group' do
              mock(Railsthemes::Utils).add_gem_to_gemfile('compass-rails', version: '~> 1.1.0')
              @installer.add_needed_gems
            end
          end

          context 'gem is present' do
            it 'should not try to add it' do
              write_gemfiles_using_gems ['compass-rails']
              do_not_allow(Railsthemes::Utils).add_gem_to_gemfile('compass-rails')
              @installer.add_needed_gems
            end
          end
        end

        describe 'zurb-foundation' do
          context 'gem is not present' do
            it 'should add it without group' do
              mock(Railsthemes::Utils).add_gem_to_gemfile('zurb-foundation', version: '~> 4.0')
              @installer.add_needed_gems
            end
          end

          context 'gem is present' do
            it 'should not try to add it' do
              write_gemfiles_using_gems ['zurb-foundation']
              do_not_allow(Railsthemes::Utils).add_gem_to_gemfile('zurb-foundation')
              @installer.add_needed_gems
            end
          end
        end

        describe 'turbo-sprockets-rails3' do
          it 'should not add it, since we are above Rails 3' do
            do_not_allow(Railsthemes::Utils).add_gem_to_gemfile('turbo-sprockets-rails3')
            @installer.add_needed_gems
          end
        end
      end

      context 'Rails < 4.0.0 app' do
        before do
          stub(Railsthemes::GemfileUtils).rails_version { '3.2.14' }
        end

        describe 'compass-rails' do
          context 'gem is not present' do
            it 'should add it with group' do
              mock(Railsthemes::Utils).add_gem_to_gemfile('compass-rails', group: 'assets')
              @installer.add_needed_gems
            end
          end

          context 'gem is present' do
            it 'should not try to add it' do
              write_gemfiles_using_gems :assets => ['compass-rails']
              do_not_allow(Railsthemes::Utils).add_gem_to_gemfile('compass-rails')
              @installer.add_needed_gems
            end
          end
        end

        describe 'zurb-foundation' do
          context 'gem is not present' do
            it 'should add it without group' do
              mock(Railsthemes::Utils).add_gem_to_gemfile('zurb-foundation', version: '~> 4.0', group: 'assets')
              @installer.add_needed_gems
            end
          end

          context 'gem is present' do
            it 'should not try to add it' do
              write_gemfiles_using_gems :assets => ['zurb-foundation']
              do_not_allow(Railsthemes::Utils).add_gem_to_gemfile('zurb-foundation')
              @installer.add_needed_gems
            end
          end
        end

        describe 'turbo-sprockets-rails3' do
          it 'should not add it, since we are above Rails 3' do
            mock(Railsthemes::Utils).add_gem_to_gemfile('turbo-sprockets-rails3', group: 'assets')
            @installer.add_needed_gems
          end

          it 'should not re-add it if it already exists' do
            write_gemfiles_using_gems :assets => ['turbo-sprockets-rails3']
            do_not_allow(Railsthemes::Utils).add_gem_to_gemfile('turbo-sprockets-rails3')
            @installer.add_needed_gems
          end
        end
      end
    end
  end

  describe '#create_railsthemes_demo_routes' do
    before do
      contents = <<-EOS
RailsApp::Application.routes.draw do
  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
  # root :to => 'home/index'
end
      EOS
      create_file 'config/routes.rb', :content => contents
    end

    it 'should add routing if it has not been generated yet' do
      @installer.create_railsthemes_demo_routes
      File.read('config/routes.rb').split("\n").grep(
        /match '\/' => 'railsthemes#index'/
      ).count.should == 1
    end

    it 'should not readd routing' do
      @installer.create_railsthemes_demo_routes
      @installer.create_railsthemes_demo_routes
      File.read('config/routes.rb').split("\n").grep(
        /match '\/' => 'railsthemes#index'/
      ).count.should == 1
    end

    context 'when no root route exists' do
      it 'should add root route' do
        @installer.create_railsthemes_demo_routes
        File.read('config/routes.rb').split("\n").grep(
          '  root :to => "railsthemes/railsthemes#index"'
        ).count.should == 1
      end
    end

    context 'when root route exists' do
      it 'should not add another root route' do
        @installer.create_railsthemes_demo_routes
        @installer.create_railsthemes_demo_routes
        File.read('config/routes.rb').split("\n").grep(
          '  root :to => "railsthemes/railsthemes#index"'
        ).count.should == 1
      end
    end
  end

  describe '#add_to_asset_precompilation_list' do
    it 'should add it to the list if the line is not there yet' do
      create_file 'config/environments/production.rb', :content => <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )
end
      EOS
      @installer.add_to_asset_precompilation_list 'magenta'
      count = File.read('config/environments/production.rb').split("\n").grep(
  /^\s*config.assets.precompile \+= %w\( railsthemes_magenta\.js railsthemes_magenta\.css \)$/).count
      count.should == 1
    end

    it 'should not add it again if the line is there already' do
      create_file 'config/environments/production.rb', :content => <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( railsthemes_magenta.js railsthemes_magenta.css )
  # config.assets.precompile += %w( search.js )
end
      EOS
      @installer.add_to_asset_precompilation_list 'magenta'
      count = File.read('config/environments/production.rb').split("\n").grep(
  /^\s*config.assets.precompile \+= %w\( railsthemes_magenta\.js railsthemes_magenta\.css \)$/).count
      count.should == 1
    end

    it 'should add it to the list if there is a different theme already installed' do
      create_file 'config/environments/production.rb', :content => <<-EOS
BaseApp::Application.configure do
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( railsthemes_orange.js railsthemes_orange.css )
  # config.assets.precompile += %w( search.js )
end
      EOS
      @installer.add_to_asset_precompilation_list 'magenta'
      count = File.read('config/environments/production.rb').split("\n").grep(
  /^\s*config.assets.precompile \+= %w\( railsthemes_magenta\.js railsthemes_magenta\.css \)$/).count
      count.should == 1
      count = File.read('config/environments/production.rb').split("\n").grep(
  /^\s*config.assets.precompile \+= %w\( railsthemes_orange\.js railsthemes_orange\.css \)$/).count
      count.should == 1
    end
  end

  describe '#comment_out_formtastic_if_user_does_not_use_formtastic' do
    before do
      @filename = 'app/assets/stylesheets/railsthemes_themename.css'
      create_file @filename, :content => <<-EOS
/*
 *= require formtastic
 */
      EOS
    end

    context 'user is using formtastic' do
      before do
      end

      it 'should not comment out the line' do
        write_gemfiles_using_gems 'formtastic'
        @installer.comment_out_formtastic_if_user_does_not_use_formtastic 'themename'
        File.read(@filename).split("\n").grep(/\*= require formtastic/).count.should == 1
      end
    end

    context 'user is not using formtastic' do
      it 'should comment out the line' do
        @installer.comment_out_formtastic_if_user_does_not_use_formtastic 'themename'
        File.read(@filename).split("\n").grep(/\* require formtastic/).count.should == 1
      end
    end
  end

  describe '#add_sass_module_line' do
      before do
        create_file 'config/application.rb', :content => <<-EOS
module Rails3214
  class Application < Rails::Application
  end
end
        EOS
      end

    context 'the content does not already exist' do
      it 'should add the lines' do
        @installer.add_sass_module_line
        File.read('config/application.rb').split("\n").grep(/sass.rb/).count.should == 1
      end
    end

    context 'the line already exists' do
      it 'should not add it again' do
        @installer.add_sass_module_line
        @installer.add_sass_module_line
        File.read('config/application.rb').split("\n").grep(/sass.rb/).count.should == 1
      end
    end
  end

end

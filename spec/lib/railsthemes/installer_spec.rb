require 'spec_helper'
require 'railsthemes'

describe Railsthemes::Installer do
  def using_gems *gems
    "GEM\nremote: https://rubygems.org/\nspecs:\n" +
      gems.map{|gem| "    #{gem}"}.join("\n") +
      "\nGEM\n  remote: https://rubygems.org/"
  end

  before do
    @logger = Logger.new(File.join Dir.tmpdir, 'railsthemes.log')
    @installer = Railsthemes::Installer.new @logger
    stub(@installer).ensure_in_rails_root
    stub(@installer).generate_tempdir_name { '/tmp' }
    FileUtils.touch('Gemfile.lock')
  end

  describe :install_from_file_system do
    context 'when the filepath is a directory' do
      it 'should copy the files from that directory into the Rails app' do
        FileUtils.mkdir_p('filepath/base')
        FileUtils.touch('filepath/base/a')
        FileUtils.touch('filepath/base/b')
        FileUtils.mkdir_p('filepath/gems')
        mock(@installer).post_copying_changes

        @installer.install_from_file_system('filepath')
        File.exists?('a').should be_true
        File.exists?('b').should be_true
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
        mock(@installer).print_usage_and_abort(/either/)
        @installer.install_from_file_system("does not exist")
      end
    end
  end

  describe :install_gems_from do
    it 'should install the gems that we specify that match' do
      FakeFS::FileSystem.clone('spec/fixtures')
      @installer.install_gems_from("spec/fixtures/blank-assets", ['formtastic', 'kaminari'])
      File.exist?(File.join('app', 'assets', 'stylesheets', 'formtastic.css.scss')).should be_true
      File.exist?(File.join('app', 'assets', 'stylesheets', 'kaminari.css.scss')).should be_false
      File.exist?(File.join('app', 'assets', 'stylesheets', 'simple_form.css.scss')).should be_false
    end
  end

  describe :install_from_archive do
    it 'should extract the archive correctly' do
      mock(@installer).install_from_file_system '/tmp'
      mock(@installer).untar_string('filepath', anything) { 'untar string' }
      mock(Railsthemes::Safe).system_call('untar string')
      @installer.install_from_archive 'filepath'
    end
  end

  describe :untar_string do
    it 'should return correct value for *.tar.gz file' do
      result = @installer.untar_string 'file.tar.gz', 'newdirpath'
      result.should == 'tar -zxf file.tar.gz -C newdirpath'
    end
  end

  describe :archive? do
    it 'should be true for tar.gz file' do
      @installer.archive?('test/a/b/c/d.tar.gz').should be_true
    end

    it 'should be false for other extensions' do
      @installer.archive?('test/a/b/c.tar/d.zip').should be_false
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
         File.exist?(filename).should be_true, "#{filename} was not present"
      end
      File.open('app/assets/stylesheets/style.css.erb').each do |line|
        line.should match /style.css.erb/
      end
    end

    before do
      stub(@installer).post_copying_changes
      FakeFS::FileSystem.clone('spec/fixtures')
    end

    it 'should extract correctly from directory' do
      filename = 'spec/fixtures/blank-assets'
      @installer.install_from_file_system filename
      verify_end_to_end_operation
    end

    # TODO need to use a pure ruby solution to get this to mock in the file system right
    it 'should extract correctly from archive' do
      pending 'needs pure ruby untar solution'
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

  describe :download_from_code do
    context 'when a gemfile.lock is not present' do
      it 'should fail with a good message' do
        File.unlink('Gemfile.lock')
        mock(Railsthemes::Safe).log_and_abort(/could not find/)
        @installer.download_from_code 'anything'
      end
    end

    context 'when a gemfile.lock is present' do
      before do
        mock(@installer).check_vcs_status
        mock(@installer).send_gemfile('panozzaj@gmail.com:code')
      end

      it 'should download the file correctly when valid configuration' do
        FakeWeb.register_uri :get,
          /download\?code=panozzaj@gmail.com:code&config=haml,scss/,
          :body => 'auth_url'
        mock(@installer).get_primary_configuration('') { 'haml,scss' }
        mock(Railsthemes::Utils).download_file_to('auth_url', '/tmp/archive.tar.gz')
        mock(@installer).install_from_archive '/tmp/archive.tar.gz'
        @installer.download_from_code 'panozzaj@gmail.com:code'
      end

      it 'should fail with an error message on any error message' do
        FakeWeb.register_uri :get,
          'https://railsthemes.com/download?code=panozzaj@gmail.com:code&config=',
          :body => '', :status => ['401', 'Unauthorized']
        mock(@installer).get_primary_configuration('') { '' }
        mock(Railsthemes::Safe).log_and_abort(/didn't understand/)
        @installer.download_from_code 'panozzaj@gmail.com:code'
      end
    end
  end

  describe '#get_primary_configuration' do
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

  describe :check_vcs_status do
    context 'when git used' do
      before do
        Dir.mkdir('.git')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '# modified: installer_spec.rb' }
        mock(Railsthemes::Safe).log_and_abort(/pending changes/)
        @installer.check_vcs_status
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('git status -s') { '' }
        @installer.check_vcs_status
      end
    end

    context 'when hg used' do
      before do
        Dir.mkdir('.hg')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('hg status') { '? test.txt' }
        mock(Railsthemes::Safe).log_and_abort(/pending changes/)
        @installer.check_vcs_status
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('hg status') { '' }
        @installer.check_vcs_status
      end
    end

    context 'when subversion used' do
      before do
        Dir.mkdir('.svn')
      end

      it 'should exit when the vcs is unclean' do
        mock(Railsthemes::Safe).system_call('svn status') { 'M something.txt' }
        mock(Railsthemes::Safe).log_and_abort(/pending changes/)
        @installer.check_vcs_status
      end

      it 'should do nothing significant when the vcs is clean' do
        mock(Railsthemes::Safe).system_call('svn status') { '' }
        @installer.check_vcs_status
      end
    end
  end
end

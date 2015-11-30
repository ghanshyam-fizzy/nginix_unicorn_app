set :stages, %w(production)     #various environments
load "deploy/assets"                    #precompile all the css, js and images... before deployment..
require 'bundler/capistrano'            # install all the new missing plugins...
require 'capistrano/ext/multistage'     # deploy on all the servers..
require 'rvm/capistrano'                # if you are using rvm on your server..
require './config/boot'

before "deploy:assets:precompile","deploy:config_symlink"

set :shared_children, shared_children + %w{public/uploads}
after "deploy:update", "deploy:cleanup" #clean up temp files etc.
after "deploy:update_code","deploy:migrate"

set(:application) { "nginix_unicorn_app" }

set :rvm_ruby_string, '2.1.5'             # ruby version you are using...
set :rvm_type, :user

server "159.203.89.141", :app, :web, :db, :primary => true
set (:deploy_to) { "/home/deploy/#{application}/#{stage}" }
set :user, 'deploy'
set :keep_releases, 10
set :repository, "https://github.com/ghanshyam-fizzy/nginix_unicorn_app.git"
set :use_sudo, false
set :scm, :git
default_run_options[:pty] = true
ssh_options[:forward_agent] = true
set :deploy_via, :remote_cache
set :git_shallow_clone, 1
set :git_enable_submodules, 1

namespace :deploy do

  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  desc 'Congifure symlinks like database.yml'
  task :config_symlink do
    run "ln -sf #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  # run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    # put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after 'deploy:setup', 'deploy:setup_config'


  desc 'Make sure local git is in sync with remote.'
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts 'WARNING: HEAD is not the same as origin/master'
      puts 'Run `git push` to sync changes.'
      exit
    end
  end
  before 'deploy', 'deploy:check_revision'

end

# namespace :carrierwave do
#   task :symlink, roles: :app do
#     run "ln -nfs #{shared_path}/uploads/ #{release_path}/public/uploads"
#   end
#   after "deploy:finalize_update", "carrierwave:symlink"
# end

require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rvm'

# Basic settings:
set :domain,     'xxx.xxx.xxx.xxx'
set :deploy_to,  '/path/to/my/app'
set :repository, 'git@bitbucket.org:account/repo.git'
set :branch,     'master'


# Manually create these
set :shared_paths, ['config/database.yml', 'log']


# Optional settings:
set :user, 'rails'    # Username in the server to SSH to.
set :ssh_falgs, '-A'




# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  set :rvm_path, '/home/rails/.rvm/bin/rvm'
  invoke :'rvm:use[ruby-2.0.0-p451]'
end




task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[touch "#{deploy_to}/shared/config/database.yml"]
  queue  %[echo "-----> Be sure to edit 'shared/config/database.yml'."]
end


desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'

    to :launch do
      queue "touch #{deploy_to}/tmp/restart.txt"
    end
  end
end






#####
#
# Make sure to change your site.conf's log files
#  if you want to have separate logs for each site
#
#####

task :errorlog do
  queue "tail -f /var/log/nginx/ywk_error.log"
end

task :accesslog do
  queue "tail -f /var/log/nginx/ywk_access.log"
end







#####
#
# Taken from mina-puma's rakefile
#  Including mina-puma was causing rake errors
#
#####

namespace :puma do
  set :web_server, :puma

  set_default :puma_role,      -> { user }
  set_default :puma_env,       -> { fetch(:rails_env, 'production') }
  set_default :puma_config,    -> { "#{deploy_to}/#{shared_path}/config/puma.rb" }
  set_default :puma_socket,    -> { "#{deploy_to}/#{shared_path}/tmp/sockets/puma.sock" }
  set_default :puma_state,     -> { "#{deploy_to}/#{shared_path}/tmp/sockets/puma.state" }
  set_default :puma_pid,       -> { "#{deploy_to}/#{shared_path}/tmp/pids/puma.pid" }
  set_default :puma_cmd,       -> { "#{bundle_prefix} puma" }
  set_default :pumactl_cmd,    -> { "#{bundle_prefix} pumactl" }
  set_default :pumactl_socket, -> { "#{deploy_to}/#{shared_path}/tmp/sockets/pumactl.sock" }

  # Make necessary direcotries exist
  task :setup => :environment do
    queue! "#touch {deploy_to}/#{shared_path}/tmp/sockets/"
    queue! "#touch {deploy_to}/#{shared_path}/tmp/pids/"
  end

  desc 'Start puma'
  task :start => :environment do
    queue! %[
      if [ -e '#{pumactl_socket}' ]; then
        echo 'Puma is already running!';
      else
        if [ -e '#{puma_config}' ]; then
          cd #{deploy_to}/#{current_path} && #{puma_cmd} -q -d -e #{puma_env} -C #{puma_config}
        else
          cd #{deploy_to}/#{current_path} && #{puma_cmd} -q -d -e #{puma_env} -b 'unix://#{puma_socket}' -S #{puma_state} --control 'unix://#{pumactl_socket}'
        fi
      fi
    ]
  end

  desc 'Stop puma'
  task stop: :environment do
    queue! %[
      if [ -e '#{pumactl_socket}' ]; then
        cd #{deploy_to}/#{current_path} && #{pumactl_cmd} -S #{puma_state} stop
      else
        echo 'Puma is not running!';
      fi
    ]
  end

  desc 'Restart puma'
  task restart: :environment do
    invoke :'puma:stop'
    invoke :'puma:start'
  end
end


# editing NGINX
# sudo vim /etc/nginx/sites-enabled/ywk


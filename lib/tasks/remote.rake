# Common configuration for remote servers.

namespace :remote do

  desc "Open a Remote Rails Console"
  task :console do
    remote "app:console", central_servers
  end

  desc "Start the app servers"
  task :start do
    remote "app:start", app_servers
  end

  desc "Restart the app servers"
  task :restart do
    remote "app:restart", app_servers
  end

  desc "Check the current branch on the app server."
  task :branch do
    remote "branch", app_servers
  end

end

# SSH into a given remote machine. Need to pass the environment.
rule(/^ssh:/) do |t|
  conf = configuration
  host = t.name.split(':').last
  host += ".sourceafrica.net" if host !~ /\./
  exec "ssh -A -i #{conf[:key]} #{conf[:user]}@#{host}"
end

rule(/^remote:branch:/) do |t|
  branch = t.name.split(':').last
  remote "branch:#{branch}", (central_servers + worker_servers + app_servers).uniq
end

rule(/^remote:gem:install/) do |t|
  task_name = t.name.sub(/^remote:/, '')
  remote task_name, (central_servers + worker_servers + app_servers).uniq
end

rule(/^gem:install/) do |t|
  # rake gem:install:jammit/0.5.1
  full_gem = t.name.split(':').last
  gem_name, gem_version = *full_gem.split('/')
  version = gem_version ? "--version #{gem_version}" : ""
  sh "sudo gem install --no-ri --no-rdoc #{gem_name} #{version}"
end

def app_servers
  case RAILS_ENV
  when 'staging'    then ['staging.sourceafrica.net']
  when 'production' then ['app01.sourceafrica.net']
  end
end

def central_servers
  case RAILS_ENV
  when 'staging'    then ['staging.sourceafrica.net']
  when 'production' then ['db01.sourceafrica.net']
  end
end

def search_servers
  case RAILS_ENV
  when 'staging'    then ['staging.sourceafrica.net']
  when 'production' then ['solr01.sourceafrica.net']
  end
end

def worker_servers
  case RAILS_ENV
  when 'staging'    then ['staging.sourceafrica.net']
  when 'production' then ['worker01.sourceafrica.net', 'worker02.sourceafrica.net', 'worker03.sourceafrica.net', 'worker04.sourceafrica.net', 'worker05.sourceafrica.net', 'worker06.sourceafrica.net']
  end
end

def configuration
  case RAILS_ENV
  when 'staging'    then {:user => 'ubuntu', :dir => '~/sourceAFRICA', :key => 'secrets/keys/sourceafrica.pem'}
  when 'production' then {:user => 'ubuntu', :dir => '~/sourceAFRICA', :key => 'secrets/keys/sourceafrica.pem'}
  end
end

def remote(commands, machines)
  conf    = configuration
  todo    = []
  threads = []
  todo << "cd #{conf[:dir]}"
  todo << "./bin/bundle install"
  todo << "./bin/rake #{RAILS_ENV} #{[commands].flatten.join(' ')}"
  machines.each do |host|
    threads << Thread.new do
      puts "\n-- #{host} --"
      prefix = machines.many? ? sprintf("%-20s", host.gsub(/\..*$/,'') ) : ''
      Net::SSH.start( host, conf[:user], keys: conf[:key], paranoid: false) do |ssh|
        ssh.shell do |sh|
          process = sh.execute( todo.join(' && ') )
          process.on_output do |shell, line|
            line.chomp!
            puts prefix+line unless line.blank?
          end
          sh.wait!
          sh.execute! 'exit'
        end
      end
    end
    threads.each{ |t| t.join }
  end
end

Dir.glob('./{controllers,services,values,forms}/*.rb')
  .each do |file|
  require file
end

require 'sinatra/activerecord/rake'
require 'config_env/rake_tasks'
require 'rake/testtask'

task default: [:local_and_running]

desc 'Run specs'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/*_spec.rb'
end

desc 'Local and running'
task :local_and_running do
  Rake::Task['local:local_and_running'].invoke
end

desc 'Heroku and running'
task :heroku_and_running do
  Rake::Task['heroku:up_and_running'].invoke
end

namespace :local do
  desc 'Bundle Install'
  task :bundle_install do
    system 'bundle install --without production'
  end

  desc 'Set up local'
  task local_and_running: [:bundle_install] do
  end
end

namespace :heroku do
  desc 'Start a heroku'
  task :create_heroku do
    system "heroku create #{ENV['APP_NAME']}"
  end

  desc 'Push master to heroku'
  task :push_to_heroku do
    system 'git push -f heroku master'
  end

  desc 'Transfer heroku environment variables'
  task :transfer_config_env do
    system 'rake config_env:heroku'
  end

  desc 'And it\'s a wrap'
  task up_and_running: [:create_heroku, :push_to_heroku,
                        :transfer_config_env] do
  end
end

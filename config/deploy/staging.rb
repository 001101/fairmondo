set :stage, :staging

server '78.109.61.137', user: 'deploy', roles: %w{web app db sidekiq console}

set :branch, ENV['BRANCH_NAME'] || 'develop'

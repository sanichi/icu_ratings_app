namespace :deploy do
  desc "Make sure there is something to deploy"
  task :check_revision do
    on roles :web do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        puts "WARNING: HEAD is not the same as origin/master"
        print "Are you sure you want to proceed with the deployment? "
        ask :choice, "No"
        unless fetch(:choice).match(/\A(y(e(s|p|ah))?|ok)\z/i)
          puts "Run 'git push' to sync changes"
          exit
        end
      end
    end
  end

  before :deploy, "deploy:check_revision"
end

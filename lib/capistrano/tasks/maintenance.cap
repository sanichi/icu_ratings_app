namespace :deploy do
  namespace :web do
    desc "Present a maintenance page to visitors using REASON and BACK enviroment variables (or defaults)."
    task :disable do
      on roles :web do
        within release_path do
          upload! maintenance_html, "/var/apps/ratings/current/#{fetch(:maintenance_file)}"  # note: upload! doesn't yet honour "within" yet (sshkit v1.0.0)
          execute :chmod, "644", fetch(:maintenance_file)
        end
      end
    end

    desc "Remove the maintenance file"
    task :enable do
      on roles :web do
        within release_path do
          execute :rm, fetch(:maintenance_file)
        end
      end
    end

    def maintenance_html
      require "haml"
      template = File.read("app/views/layouts/maintenance.html.haml")
      engine = Haml::Engine.new(template, format: :html5, attr_wrapper: '"')
      reason = ENV["REASON"] || "maintenance"
      back = ENV["BACK"] || "shortly"
      StringIO.new(engine.render(binding))
    end
  end
end

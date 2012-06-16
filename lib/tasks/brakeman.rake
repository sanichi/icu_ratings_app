namespace :brakeman do
  desc "Run Brakeman"
  task :run, :output_file do |t, args|
    #require 'brakeman'
    #Brakeman.run :app_path => ".", :output_file => args[:output_file], :print_report => true
    system "bin/brakeman -o #{args[:output_file] || 'tmp/brakeman.html'}"
  end
end

namespace :isimud do
  desc 'Synchronize specified models (default is all synchronized models)'
  task :sync => :environment do
    require 'chronic_duration'
    require 'isimud'

    models = $*.drop(1)
    models = Isimud::ModelWatcher.watched_models if models.empty?

    start_time = Time.now
    puts "Synchronizing models: #{models.join(', ')}"
    models.each do |model|
      klass = model.constantize
      puts "\n#{klass.to_s}"
      klass.synchronize(output: $stdout)
    end
    end_time = Time.now
    puts "Finished synchronization in #{ChronicDuration.output(end_time - start_time)}."
  end
end
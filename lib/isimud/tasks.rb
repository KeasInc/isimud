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
      klass = model.classify.constantize
      puts "\n#{klass.to_s}"
      count = 0
      klass.find_each do |m|
        next unless m.isimud_synchronize?
        begin
          m.isimud_sync
        rescue Bunny::ClientTimeout
          puts "\ntimeout, sleeping for 60 seconds"
          sleep(60)
          m.isimud_sync
        end
        if (count += 1) % 100 == 0
          print '.'
        end
      end
      puts "\n#{count} records synchronized"
    end
    end_time = Time.now
    puts "Finished synchronization in #{ChronicDuration.output(end_time - start_time)}."
  end
end
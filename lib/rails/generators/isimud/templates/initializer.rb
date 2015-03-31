require 'isimud'

configs = begin
  path = Rails.root.join('config', 'isimud.yml')
  YAML::load(ERB.new(IO.read(path)).result)
rescue
  Rails.logger.warn("Isimud: configuration could not be loaded at: #{path}")
  {}
end

Isimud.model_watcher_schema = Rails.configuration.database_configuration[Rails.env]['database']

config = configs[Rails.env]

config.each do |key, val|
  Isimud.config.send("#{key}=".to_sym, val)
end
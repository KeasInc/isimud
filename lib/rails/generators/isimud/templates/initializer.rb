require 'isimud'

configs = begin
  path = Rails.root.join('config', 'isimud.yml')
  YAML::load(ERB.new(IO.read(path)).result)
rescue
  Rails.logger.warn("Isimud: configuration could not be loaded at: #{path}")
  {}
end

config = configs[Rails.env]

Isimud.client_type    = config['client_type']
Isimud.client_options = config['client_options']
Isimud.logger         = config['logger'] || Rails.logger
Isimud.log_level      = config['log_level'] || Rails.configuration.log_level
Isimud.prefetch_count = config['prefetch_count']
Isimud.server         = config['server']

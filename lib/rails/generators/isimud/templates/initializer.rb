require 'isimud'

configs = begin
  path = Rails.root.join('config', 'isimud.yml')
  YAML::load(ERB.new(IO.read(path)).result)
rescue
  Rails.logger.warn("Isimud: configuration could not be loaded at: #{path}")
  {}
end

config = configs[Rails.env]

Rails.logger.info("Isimud configuration: #{config.inspect}")
Isimud.client_type = config['client_type']
Isimud.logger      = Rails.logger
Isimud.server      = config['server']

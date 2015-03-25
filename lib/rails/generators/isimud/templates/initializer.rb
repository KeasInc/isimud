require 'isimud'


DEFAULT_CONFIG = {
    client_type:          :bunny,
    server:               ENV['AMQP_URL'] || 'amqp://guest:guest@localhost',
    logger:               Rails.logger,
    log_level:            :debug,
    listener_error_limit: 100,
    events_exchange:      Isimud::Event::DEFAULT_EXCHANGE,
    models_exchange:      Isimud::ModelWatcher::DEFAULT_EXCHANGE
}

configs = begin
  path = Rails.root.join('config', 'isimud.yml')
  YAML::load(ERB.new(IO.read(path)).result)
rescue
  Rails.logger.warn("Isimud: configuration could not be loaded at: #{path}")
  {}
end


config = configs[Rails.env]
config.reverse_merge!(DEFAULT_CONFIG)

Isimud.config.client_type          = config['client_type']
Isimud.config.client_options       = config['client_options']
Isimud.config.enable_model_watcher = config['enable_model_watcher']
Isimud.config.events_exchange      = config['events_exchange']
Isimud.config.listener_error_limit = config['listener_error_limit']
Isimud.config.logger               = config['logger']
Isimud.config.log_level            = config['log_level']
Isimud.config.prefetch_count       = config['prefetch_count']
Isimud.config.retry_failures       = config['retry_failures']
Isimud.config.server               = config['server']
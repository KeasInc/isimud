require 'rails'

module Isimud
  DEFAULT_CLIENT_TYPE = :bunny
  DEFAULT_SERVER      = 'amqp://guest:guest@localhost'

  DEFAULT_CONFIG = {
      client_type: DEFAULT_CLIENT_TYPE,
      server:      ENV['AMQP_URL'] || DEFAULT_SERVER
  }

  class Railtie < Rails::Railtie
    initializer 'isimud.configure' do |app|
      config = if (configs = load_config)
                 configs[Rails.env] || configs['defaults']
               else
                 {}
               end
      config.reverse_merge!(DEFAULT_CONFIG)
      Isimud.client_type = config['client_type']
      Isimud.logger      = Rails.logger
      Isimud.server      = config['server']
    end

    generators do
      require 'isimud'
    end

    private

    def load_config
      require 'erb'
      path = Rails.root.join('config', 'isimud.yml')
      YAML::load(ERB.new(IO.read(path)).result)
    rescue
      Rails.logger.warn("Isimud: configuration could not be loaded at: #{path}")
      nil
    end
  end
end

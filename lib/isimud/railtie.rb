require 'rails'

module Isimud
  class Railtie < Rails::Railtie
    initializer 'isimud.configure' do |app|
      require 'erb'
      configs = YAML::load(ERB.new(IO.read(Rails.root.join('config/isimud.yml'))).result).stringify_keys
      config = configs[Rails.env].stringify_keys
      app.config.isimud = case config['client']
      when 'bunny'
        Isimud::BunnyClient.new(config['broker_url'])
      when 'test'
        Isimud::TestClient.new
      end
    end
  end
end

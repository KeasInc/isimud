require 'rails'

module Isimud
  class Railtie < Rails::Railtie
    initializer 'isimud.configure' do |app|
      require 'erb'
      configs           = load_config
      config            = configs[Rails.env] || configs
    end

    private

    def load_config
      path = Rails.root.join('config', 'isimud.yml')
      YAML::load(ERB.new(IO.read(path)).result).stringify_keys
    rescue
      {}
    end
  end
end

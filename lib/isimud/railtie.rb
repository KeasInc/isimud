require 'rails'

module Isimud
  class Railtie < Rails::Railtie
    generators do
      require 'isimud'
    end
  end
end

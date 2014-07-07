require 'active_support'

require 'isimud/version'
require 'isimud/bunny_client'
require 'isimud/railtie' if defined?(Rails)
require 'isimud/test_client'
require 'isimud/model_watcher'

module Isimud
  mattr_accessor :client
end

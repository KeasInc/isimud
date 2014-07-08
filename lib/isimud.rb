require 'active_support/core_ext/module/attribute_accessors'
require 'isimud/version'
require 'isimud/bunny_client'
require 'isimud/railtie' if defined?(Rails)
require 'isimud/test_client'
require 'isimud/model_watcher'

module Isimud
  mattr_writer :logger, instance_writer: false

  def self.logger
    @@logger ||= Logger.new(STDOUT)
  end
end

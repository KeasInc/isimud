require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'
require 'isimud/version'
require 'isimud/bunny_client'
require 'isimud/test_client'
require 'isimud/railtie' if defined?(Rails)
require 'isimud/model_watcher'

module Isimud
  include ::ActiveSupport::Configurable

  config_accessor :client_type, :logger, :server, :default_client, :model_watcher_schema, :model_watcher_exchange

  def self.client_class
    type = "#{client_type}_client".classify
    "Isimud::#{type}".constantize
  end

  def self.client
    self.default_client ||= client_class.new(server)
  end

  def self.connect
    client.connect
  end

  def self.reconnect
    client.reconnect
  end
end

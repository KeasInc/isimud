require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'
require 'isimud/model_watcher'
require 'isimud/bunny_client'
require 'isimud/railtie' if defined?(Rails)
require 'isimud/test_client'
require 'isimud/version'


module Isimud
  include ::ActiveSupport::Configurable

  config_accessor :client_type, :client_options, :prefetch_count, :logger, :server, :default_client,
                  :model_watcher_schema, :model_watcher_exchange

  def self.client_class
    type = "#{client_type}_client".classify
    "Isimud::#{type}".constantize
  end

  def self.client
    self.default_client ||= client_class.new(server, client_options || {})
  end

  def self.connect
    client.connect
  end

  def self.reconnect
    client.reconnect
  end
end

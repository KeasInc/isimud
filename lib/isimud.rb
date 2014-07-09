require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'
require 'isimud/version'
require 'isimud/bunny_client'
require 'isimud/test_client'
require 'isimud/railtie' if defined?(Rails)
# TODO enable require 'isimud/model_watcher'

module Isimud
  include ::ActiveSupport::Configurable

  config_accessor :client_type, :logger, :server

  def self.client_class
    type = "#{client_type}_client".classify
    "Isimud::#{type}".constantize
  end

  mattr_writer :client
  def self.client
    @@client ||= client_class.new(server)
  end

  def self.connect
    client.connect
  end

  def self.reconnect
    @@client.try(:reconnect)
  end
end

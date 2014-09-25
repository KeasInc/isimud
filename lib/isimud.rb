require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'
require 'isimud/logging'
require 'isimud/client'
require 'isimud/event'
require 'isimud/model_watcher'
require 'isimud/railtie' if defined?(Rails)
require 'isimud/version'


module Isimud
  include ::ActiveSupport::Configurable

  config_accessor :client_type, :client_options, :default_client, :enable_model_watcher, :logger, :log_level,
                  :model_watcher_schema, :model_watcher_exchange, :prefetch_count, :retry_failures, :server

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

  def self.model_watcher_enabled?
    enable_model_watcher.nil? || enable_model_watcher
  end

  def self.reconnect
    client.reconnect
  end
end

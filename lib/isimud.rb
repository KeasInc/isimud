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

  # @!attribute [rw] client_type
  #   @return [Enumerable<'bunny', 'test'>] Type of client to use
  # @!attribute [rw] client_options
  #   @return [Hash] client specific options
  # @!attribute [rw] default_client
  #   @return [Isimud::Client] default client
  # @!attribute [rw] enable_model_watcher
  #   @return [Boolean] when set, send Isimud::ModelWatcher events
  # @!attribute [rw] logger
  #   @return [Logger] logger for tracing messages (Rails.logger)
  # @!attribute [rw] log_level
  #   @return [Symbol] log level (:debug)
  # @!attribute [rw] model_watcher_schema
  #   @return [String] schema name (Rails.configuration.database_configuration[Rails.env]['database'])
  # @!attribute [rw] prefetch_count
  #   @return [Integer] number of messages to fetch -- only applies to BunnyClient
  # @!attribute [rw] retry_failures
  #   @return [Boolean] when set, if an exception occurs during message processing, requeue it
  # @!attribute [rw] server
  #   @return [<String, Hash>] server connection attributes
  config_accessor :client_type, :client_options, :default_client, :enable_model_watcher, :logger, :log_level,
                  :model_watcher_schema, :model_watcher_exchange, :prefetch_count, :retry_failures, :server

                  def self.client_class
    type = "#{client_type}_client".classify
    "Isimud::#{type}".constantize
  end

  # Fetch or initialize the messaging client for this process.
  # @return [Isimud::Client] messaging client
  def self.client
    self.default_client ||= client_class.new(server, client_options || {})
  end

  # Connect to the messaging server
  def self.connect
    client.connect
  end

  # Return status of model watching mode
  def self.model_watcher_enabled?
    enable_model_watcher.nil? || enable_model_watcher
  end

  # Reconnect the messaging client
  def self.reconnect
    client.reconnect
  end
end

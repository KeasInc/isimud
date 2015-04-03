require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'
require 'isimud/logging'
require 'isimud/client'
require 'isimud/event'
require 'isimud/event_listener'
require 'isimud/event_observer'
require 'isimud/model_watcher'
require 'isimud/version'


module Isimud
  include ::ActiveSupport::Configurable
  # @!attribute [r] client_type
  #   @return [Enumerable<'bunny', 'test'>] Type of client to use
  # @!attribute [r] client_options
  #   @return [Hash] client specific options
  # @!attribute [r] default_client
  #   @return [Isimud::Client] default client
  # @!attribute [r] events_exchange
  #   @return [String] AMQP exchange used for publishing Event instances
  # @!attribute [r] enable_model_watcher
  #   @return [Boolean] when set, send Isimud::ModelWatcher messages
  # @!attribute [r] listener_error_limit
  #   @return [Integer] maximum number of exceptions allowed per hour before listener shuts down (100)
  # @!attribute [r] logger
  #   @return [Logger] logger for tracing messages (Rails.logger)
  # @!attribute [r] log_level
  #   @return [Symbol] log level (:debug)
  # @!attribute [r] model_watcher_exchange
  #   @return [String] AMQP exchange used for publishing ModelWatcher messages
  # @!attribute [r] model_watcher_schema
  #   @return [String] schema name (Rails.configuration.database_configuration[Rails.env]['database'])
  # @!attribute [r] prefetch_count
  #   @return [Integer] number of messages to fetch -- only applies to BunnyClient
  # @!attribute [r] retry_failures
  #   @return [Boolean] when set, if an exception occurs during message processing, requeue it
  # @!attribute [r] server
  #   @return [<String, Hash>] server connection attributes
  config_accessor :client_type do
    :bunny
  end
  config_accessor :client_options, :default_client, :enable_model_watcher, :model_watcher_schema, :retry_failures
  config_accessor :listener_error_limit do
    100
  end
  config_accessor :logger do
    Rails.logger
  end
  config_accessor :log_level do
    :debug
  end
  config_accessor :events_exchange do
    'events'
  end
  config_accessor :model_watcher_exchange do
    'models'
  end
  config_accessor :prefetch_count do
    100
  end
  config_accessor :server do
    ENV['AMQP_URL']
  end

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

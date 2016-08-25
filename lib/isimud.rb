require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'

module Isimud
  include ::ActiveSupport::Configurable
  # @!attribute [rw] client_type
  #   @return [Enumerable<'bunny', 'test'>] Type of client to use
  # @!attribute [rw] client_options
  #   @return [Hash] client specific options
  # @!attribute [rw] default_client
  #   @return [Isimud::Client] default client
  # @!attribute [rw] events_exchange
  #   @return [String] AMQP exchange used for publishing Event instances
  # @!attribute [rw] enable_model_watcher
  #   @return [Boolean] when set, send Isimud::ModelWatcher messages
  # @!attribute [rw] listener_error_limit
  #   @return [Integer] maximum number of uncaught exceptions allowed per hour before listener shuts down (100)
  # @!attribute [rw] logger
  #   @return [Logger] logger for tracing messages (Rails.logger)
  # @!attribute [rw] log_level
  #   @return [Symbol] log level (:debug)
  # @!attribute [rw] model_watcher_exchange
  #   @return [String] AMQP exchange used for publishing ModelWatcher messages
  # @!attribute [rw] model_watcher_schema
  #   @return [String] schema name (Rails.configuration.database_configuration[Rails.env]['database'])
  # @!attribute [rw] prefetch_count
  #   @return [Integer] number of messages to fetch -- only applies to BunnyClient
  # @!attribute [rw] retry_failures
  #   @return [Boolean|nil] whether to requeue a message if an exception occurs during processing.
  #   When set to nil, the return status from exception handlers is used. (false)
  #   @see Isimud::Client#on_exception
  # @!attribute [rw] server
  #   @return [<String, Hash>] server connection attributes ()
  config_accessor :client_type do
    :bunny
  end
  config_accessor :client_options, :default_client, :enable_model_watcher, :model_watcher_schema
  config_accessor :retry_failures do
    false
  end
  config_accessor :listener_error_limit do
    100
  end
  config_accessor :logger do
    logger
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

require 'isimud/logging'
require 'isimud/client'
require 'isimud/event'
require 'isimud/event_listener'
require 'isimud/event_observer'
require 'isimud/model_watcher'
require 'isimud/version'

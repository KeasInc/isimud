require 'active_support/core_ext/module/attribute_accessors'
require 'isimud/version'
require 'isimud/bunny_client'
require 'isimud/railtie' if defined?(Rails)
require 'isimud/test_client'
require 'isimud/model_watcher'

module Isimud
  include ActiveSupport::Configurable
  config_accessor :client_type, :server, :logger

  DEFAULT_CLIENT_TYPE = :bunny
  DEFAULT_LOGGER = Logger.new(STDOUT)
  DEFAULT_SERVER = ENV['AMQP_URL'] || 'amqp://guest:guest@localhost'

  def self.client_class
    type = "#{client_type}_client".classify
    "Isimud::#{type}".constantize
  end

  mattr_writer :client
  def self.client
    @@client ||= client_class.new(server || DEFAULT_SERVER)
  end
end

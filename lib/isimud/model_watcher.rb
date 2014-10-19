require 'active_record'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

module Isimud
  # ActiveModel mixin for sending model updates to a message server.
  module ModelWatcher
    extend ::ActiveSupport::Concern
    include Isimud::Logging

    DEFAULT_EXCHANGE = 'models'
    IGNORED_COLUMNS  = %w{id}

    included do
      cattr_accessor :isimud_watch_attributes

      after_commit :isimud_notify_created, on: :create
      after_commit :isimud_notify_updated, on: :update
      after_commit :isimud_notify_destroyed, on: :destroy
    end

    module ClassMethods
      # Set attributes to observe and include in messages. Any property method with a return value may be included
      # in the list of attributes.
      # @param [Array<String,Symbol>] attributes list of attributes / properties
      def watch_attributes(*attributes)
        self.isimud_watch_attributes = attributes.flatten.map(&:to_sym) if attributes.present?
      end

      def isimud_model_watcher_type
        respond_to?(:base_class) ? base_class.name : name
      end
    end

    # Override to set conditions for synchronizing this instance with the server (default is always)
    def isimud_synchronize?
      true
    end

    protected

    def isimud_notify_created
      isimud_send_action_message(:create)
    end

    def isimud_notify_updated
      changed_attrs = previous_changes.symbolize_keys.keys
      attributes = isimud_watch_attributes || isimud_default_attributes
      isimud_send_action_message(:update) if (changed_attrs & attributes).any?
    end

    def isimud_notify_destroyed
      isimud_send_action_message(:destroy)
    end

    def isimud_default_attributes
      self.class.column_names - IGNORED_COLUMNS
    end

    def isimud_attribute_data
      attributes = isimud_watch_attributes || isimud_default_attributes
      attributes.inject(Hash.new) { |hsh, attr| hsh[attr] = send(attr); hsh }
    end

    def isimud_model_watcher_schema
      Isimud.model_watcher_schema || if defined?(Rails)
                                       Rails.configuration.database_configuration[Rails.env]['database']
                                     end
    end

    def isimud_model_watcher_exchange
      Isimud.model_watcher_exchange || DEFAULT_EXCHANGE
    end

    def isimud_model_watcher_type
      self.class.isimud_model_watcher_type
    end

    def isimud_model_watcher_routing_key(action)
      [isimud_model_watcher_schema, isimud_model_watcher_type, action].join('.')
    end

    def isimud_send_action_message(action)
      return unless Isimud.model_watcher_enabled? && isimud_synchronize?
      payload              = {
          schema:    isimud_model_watcher_schema,
          type:      isimud_model_watcher_type,
          action:    action,
          id:        id,
          timestamp: updated_at.utc
      }
      payload[:attributes] = isimud_attribute_data unless action == :destroy
      routing_key = isimud_model_watcher_routing_key(action)
      log "Isimud::ModelWatcher#publish: exchange #{isimud_model_watcher_exchange} routing_key #{routing_key} payload #{payload.inspect}"
      Isimud.client.publish(isimud_model_watcher_exchange, routing_key, payload.to_json)
    end
  end
end

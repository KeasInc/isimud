require 'active_record'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

module Isimud
  module ModelWatcher
    extend ::ActiveSupport::Concern

    DEFAULT_EXCHANGE = 'models'
    IGNORED_COLUMNS  = %w{id created_at updated_at}

    included do
      cattr_accessor :isimud_watch_attributes

      after_commit :isimud_notify_created, on: :create
      after_commit :isimud_notify_updated, on: :update
      after_commit :isimud_notify_destroyed, on: :destroy
    end

    module ClassMethods
      def watch_attributes(*attributes)
        attributes = column_names - IGNORED_COLUMNS if attributes.empty?
        self.isimud_watch_attributes = attributes.flatten.map(&:to_sym)
      end

      def isimud_model_watcher_type
        respond_to?(:base_class) ? base_class.name : name
      end
    end

    protected

    def isimud_notify_created
      isimud_send_action_message(:create)
    end

    def isimud_notify_updated
      changed_attrs = previous_changes.symbolize_keys.keys
      isimud_send_action_message(:update) if (changed_attrs & isimud_watch_attributes).any?
    end

    def isimud_notify_destroyed
      isimud_send_action_message(:destroy)
    end

    def isimud_attribute_data
      isimud_watch_attributes.inject(Hash.new) { |hsh, attr| hsh[attr] = send(attr); hsh }
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
      return unless Isimud.model_watcher_enabled?
      payload              = {
          schema:    isimud_model_watcher_schema,
          type:      isimud_model_watcher_type,
          action:    action,
          id:        id,
          timestamp: updated_at.utc
      }
      payload[:attributes] = isimud_attribute_data unless action == :destroy
      Isimud.client.publish(isimud_model_watcher_exchange, isimud_model_watcher_routing_key(action), payload.to_json)
    end
  end
end

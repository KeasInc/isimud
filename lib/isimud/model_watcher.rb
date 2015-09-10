require 'active_record'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

module Isimud
  # ActiveModel mixin for sending model updates to a message server.
  module ModelWatcher
    extend ::ActiveSupport::Concern
    include Isimud::Logging

    mattr_accessor :watched_models

    DEFAULT_EXCHANGE = 'models'
    IGNORED_COLUMNS  = %w{id}

    included do
      ModelWatcher.watched_models ||= Array.new
      ModelWatcher.watched_models << self.name
      cattr_accessor :isimud_watch_attributes
      cattr_accessor :sync_includes

      after_commit :isimud_notify_created, on: :create
      after_commit :isimud_notify_updated, on: :update
      after_commit :isimud_notify_destroyed, on: :destroy
    end

    module ClassMethods
      # Set attributes to observe and include in messages. Any property method with a return value may be included
      # in the list of attributes.
      # @param [Array<String,Symbol>] attributes list of attributes / properties
      def watch_attributes(*attributes)
        self.isimud_watch_attributes = attributes.flatten.map(&:to_s) if attributes.present?
      end

      # Include the following tables when fetching records for synchronization
      def sync_include(_sync_includes)
        self.sync_includes = _sync_includes
      end

      # Synchronize instances of this model with the data warehouse. This is accomplished by calling
      # isimud_notify_updated() on each instance fetched from the database.
      # @param [Hash] options synchronize options
      # @option options [ActiveRecord::Relation] :where where_clause filter for limiting records to sync. By default, all records are synchronized.
      # @option options [IO] :output optional stream for writing progress. A '.' is printed for every 100 records synchronized.
      # @return [Integer] number of records synchronized
      def synchronize(options = {})
        where_clause = options[:where] || {}
        output       = options[:output] || nil
        count        = 0
        query        = self.where(where_clause)
        query        = query.includes(sync_includes) if sync_includes
        query.find_each do |m|
          next unless m.isimud_synchronize?
          begin
            m.isimud_sync
          rescue Bunny::ClientTimeout, Timeout::Error => e
            output && output.print("\n#{e}, sleeping for 10 seconds")
            sleep(10)
            m.isimud_sync
          end
          if (count += 1) % 100 == 0
            output && output.print('.')
          end
          if (count % 1000) == 0
            GC.start
          end
        end
        count
      end

      def isimud_model_watcher_type
        (respond_to?(:base_class) ? base_class.name : name).demodulize
      end
    end

    # Override to set conditions for synchronizing this instance with the server (default is always)
    def isimud_synchronize?
      true
    end

    def isimud_sync
      isimud_send_action_message(:update)
    end

    protected

    def isimud_notify_created
      isimud_send_action_message(:create)
    end

    def isimud_notify_updated
      changed_attrs = previous_changes.keys
      attributes    = isimud_watch_attributes || isimud_default_attributes
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
      Isimud.model_watcher_exchange
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
          timestamp: (updated_at || Time.now).utc
      }
      payload[:attributes] = isimud_attribute_data unless action == :destroy
      routing_key          = isimud_model_watcher_routing_key(action)
      log "Isimud::ModelWatcher#publish: exchange #{isimud_model_watcher_exchange} routing_key #{routing_key} payload #{payload.inspect}"
      Isimud.client.publish(isimud_model_watcher_exchange, routing_key, payload.to_json)
    end
  end
end

require 'active_record'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

# Module for attaching and listening to events
#
# Note: the following columns must be defined in your model:
#   :exchange_routing_keys text
module Isimud
  module EventObserver
    extend ::ActiveSupport::Concern
    include Isimud::Logging

    mattr_accessor :observed_models do
      Array.new
    end

    mattr_accessor :observed_mutex do
      Mutex.new
    end

    included do
      include Isimud::ModelWatcher unless self.include?(Isimud::ModelWatcher)
      register_class
      before_save :set_routing_keys
      serialize :exchange_routing_keys, Array
      after_commit :create_queue, on: :create
      after_commit :update_queue, on: :update
      after_commit :delete_queue, on: :destroy
    end

    # Event handling hook. Override in your class.
    def handle_event(event)
      logger.warn("Isimud::EventObserver#handle_event not implemented for #{event_queue_name}")
    end

    # Routing keys that are bound to the event queue. Override in your subclass
    def routing_keys
      []
    end

    # Returns true if this instance is enabled for listening to events. Override in your subclass.
    def enable_listener?
      true
    end

    # Exchange used for listening to events. Override in your subclass if you want to specify an alternative exchange for
    # events. Otherwise
    def observed_exchange
      nil
    end

    # Create or attach to a queue on the specified exchange. When an event message that matches the observer's routing keys
    # is received, parse the event and call handle_event on same.
    # Returns the consumer for the observer
    def observe_events(client, default_exchange)
      client.bind(event_queue_name, observed_exchange || default_exchange) do |message|
        event = Event.parse(message)
        handle_event(event)
      end
    end

    def event_queue_name
      self.class.event_queue_name(id)
    end

    def isimud_client
      Isimud.client
    end

    private

    def create_queue
      exchange = observed_exchange || Isimud.events_exchange
      log "Isimud::EventObserver: creating queue #{event_queue_name} on exchange #{exchange} with bindings [#{exchange_routing_keys.join(',')}]"
      isimud_client.create_queue(event_queue_name, exchange, routing_keys: exchange_routing_keys)
    end

    def update_queue
      routing_key_changes = previous_changes[:exchange_routing_keys]
      return unless routing_key_changes
      exchange     = observed_exchange || Isimud.events_exchange
      prev_keys    = routing_key_changes[0] || []
      current_keys = routing_key_changes[1] || []
      queue        = isimud_client.find_queue(event_queue_name)
      (prev_keys - current_keys).each { |key| queue.unbind(exchange, routing_key: key) }
      (current_keys - prev_keys).each { |key| queue.bind(exchange, routing_key: key) }
    end

    def delete_queue
      isimud_client.delete_queue(event_queue_name)
    end

    def set_routing_keys
      self.exchange_routing_keys = routing_keys
    end

    module ClassMethods
      # Method used to retrieve active observers. Override in your EventObserver class
      def find_active_observers
        []
      end

      def queue_prefix
        Rails.application.class.parent_name.downcase
      end

      def event_queue_name(id)
        [queue_prefix, base_class.name.underscore, id].join('.')
      end

      protected

      def register_class
        Isimud::EventObserver.observed_mutex.synchronize do
          unless Isimud::EventObserver.observed_models.include?(self.base_class)
            Rails.logger.info("Isimud::EventObserver: registering #{self.base_class}")
            Isimud::EventObserver.observed_models << self.base_class
          end
        end
      end
    end
  end
end

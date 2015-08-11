require 'active_record'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

# Module for attaching and listening to events
module Isimud
  module EventObserver
    extend ::ActiveSupport::Concern
    include Isimud::Logging

    mattr_accessor :observed_models do
      Array.new
    end

    mattr_reader :observed_mutex do
      Mutex.new
    end

    # Event handling hook. Override in your class.
    def handle_event(event)
      Rails.logger.warn("Isimud::EventObserver#handle_event not implemented for #{event_queue_name}")
    end

    # Routing keys that are bound to the event queue. Override in your subclass
    def routing_keys
      []
    end

    # Create or attach to a queue on the specified exchange. When an event message that matches the observer's routing keys
    # is received, parse the event and call handle_event on same.
    def observe_events(client, exchange)
      client.bind(self.class.event_queue_name(id), exchange, *routing_keys) do |message|
        event = Event.parse(message)
        handle_event(event)
      end
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

    included do
      include Isimud::ModelWatcher unless self.include?(Isimud::ModelWatcher)
      register_class
    end
  end
end

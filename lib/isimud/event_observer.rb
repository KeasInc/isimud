require 'active_record'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

# Module for attaching and listening to events
module Isimud
  module EventObserver
    extend ::ActiveSupport::Concern
    include Isimud::Logging

    included do
      include Isimud::ModelWatcher unless self.include?(Isimud::ModelWatcher)
    end

    # Event handling hook. Override in your class.
    def handle_event(event)
      Rails.logger.warn("Isimud::EventObserver#handle_event not implemented for #{event_queue_name}")
    end

    # Routing keys that are bound to the event queue. Override in your subclass
    def routing_keys
      []
    end

    def observe_events(client, exchange)
      client.bind(event_queue_name, exchange, *routing_keys) do |message|
        event = Event.parse(message)
        handle_event(event)
      end
    end

    def queue_prefix
      Rails.application.class.parent_name.downcase
    end

    def event_queue_name
      [queue_prefix, self.class.name.underscore, self.id].join('.')
    end
  end
end

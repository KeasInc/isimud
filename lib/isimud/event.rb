require 'active_support'

module Isimud
  class Event
    include Isimud::Logging
    attr_accessor :type, :action, :user_id, :occurred_at, :eventful_type, :eventful_id, :parameters

    EXCHANGE_NAME = 'events'
    DEFAULT_TYPE  = :model

    # Initialize a new Event
    # @overload Event.new(user, eventful, parameters)
    #   @param[#id] user user associated by the event
    #   @param[ActiveRecord::Base] eventful object associated with event
    #   @param[Hash] parameters optional additional parameters
    # @overload Event.new(attributes)
    #   @param[Hash] attributes event attributes
    #   @option attributes [Integer] :user_id ID of User associated with event
    #   @option attributes [String] :eventful_type class of object associated with event
    #   @option attributes [Integer] :eventful_id id of object associated with event
    #   @option attributes [ActiveRecord::Base] :eventful object associated with event. This sets :eventful_type and :eventful_id.
    #   @option attributes [String] :type event type
    #   @option attributes [String] :action event action
    #   @option attributes [Time] :occurred_at date and time event occurred (defaults to now)
    #   @option attributes [Hash] :parameters additional parameters
    def initialize(*args)
      options = args.extract_options!.with_indifferent_access

      self.type        = options.delete(:type).try(:to_sym) || DEFAULT_TYPE
      self.action      = options.delete(:action).try(:to_sym)
      self.user_id     = options.delete(:user_id)
      self.occurred_at = if (occurred = options.delete(:occurred_at))
                           occurred.kind_of?(String) ? Time.parse(occurred) : occurred
                         else
                           Time.now.utc
                         end

      eventful_object = options.delete(:eventful)

      if args.length > 0
        self.parameters = options
        if (user = args.shift)
          self.user_id = user.id
        end
        eventful_object ||= args.shift
      end

      if eventful_object
        self.eventful_type = eventful_object.class.base_class.name
        self.eventful_id   = eventful_object.id
      else
        self.eventful_type = options.delete(:eventful_type)
        self.eventful_id   = options.delete(:eventful_id)
      end

      self.parameters = options.delete(:parameters) || options

    end

    def routing_key
      [type.to_s, eventful_type, eventful_id, action].compact.join('.')
    end

    # Return hash of data to be serialized to JSON
    # @option options [Boolean] :omit_parameters when set, do not include parameters in data
    # @return [Hash] data to serialize
    def as_json(options = {})
      session_id = parameters.delete(:session_id) || Thread.current[:keas_session_id]

      data              = {type: type, action: action, user_id: user_id, occurred_at: occurred_at,
                           eventful_type: eventful_type, eventful_id: eventful_id, session_id: session_id}
      data[:parameters] = parameters unless options[:omit_parameters]
      data
    end

    def serialize
      self.to_json
    end

    class << self
      def parse(data)
        Event.new(JSON.parse(data))
      end

      def publish(*args)
        Event.new(*args).publish
      end
      alias_method :dispatch, :publish
    end

    def publish
      data = self.serialize
      log "Event#publish: #{self.inspect}"
      Isimud.client.publish(EXCHANGE_NAME, routing_key, data)
    end
  end
end

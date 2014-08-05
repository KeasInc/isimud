require 'active_support'

module Isimud
  class Event
    include Isimud::Logging
    attr_accessor :type, :action, :user_id, :occurred_at, :eventful_type, :eventful_id, :parameters

    EXCHANGE_NAME = 'events'
    DEFAULT_TYPE = :model

    # Initialize a new Event
    # @overload Event.new(user, eventful, parameters)
    #   @param[#id] user user associated by the event
    #   @param[ActiveRecord::Base] eventful object associated with event
    #   @param[Hash] parameters optional additional parameters
    # @overload Event.new(attributes)
    #   @param[Hash] attributes event attributes
    #   @option attributes [Integer] :user_id ID of User associated with event
    #   @option attributes [ActiveRecord::Base] :eventful object associated with event
    #   @option attributes [String] :type event type
    #   @option attributes [String] :action event action
    #   @option attributes [Time] :occurred_at date and time event occurred (defaults to now)
    #   @option attributes [Hash] :parameters additional parameters
    def initialize(*args)
      options = args.extract_options!.with_indifferent_access

      self.type    = options.delete(:type).try(:to_sym) || DEFAULT_TYPE
      self.action  = options.delete(:action).try(:to_sym)
      self.user_id = options.delete(:user_id)
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

      self.parameters    = options.delete(:parameters) || options

    end

    def routing_key
      [type.to_s, eventful_type, eventful_id, action].compact.join('.')
    end

    def as_json(options)
      session_id = parameters.delete(:session_id) || Thread.current[:keas_session_id]

      {:type          => type, :action => action, :user_id => user_id, :occurred_at => occurred_at,
       :eventful_type => eventful_type, :eventful_id => eventful_id, :parameters => parameters,
       :session_id    => session_id}
    end

    def serialize
      self.to_json
    end

    class << self
      def parse(data)
        Event.new(JSON.parse(data))
      end

      def dispatch(user, eventful_object = nil, parameters = {})
        Event.new(user_id: user.id, eventful: eventful_object, parameters: parameters).fire
      end
    end

    def fire
      data = self.serialize
      log "Event#fire: #{self.inspect}"
      Isimud.client.publish(EXCHANGE_NAME, routing_key, data)
    end
  end
end
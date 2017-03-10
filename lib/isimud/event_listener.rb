require 'isimud'
require 'thread'

module Isimud
  # Daemon process manager for monitoring event queues.
  # Known EventObserver models and their instances automatically registered upon startup. It is also possible to
  # define ad-hoc queues and handlers by extending
  # In addition, ad-hoc event managing may be set up by extending bind_queues() and making the appropriate subscribe
  # calls directly.
  #
  # =====================================
  # Threads created by the daemon process
  # =====================================
  #
  # Upon startup, EventListener operates using the following threads:
  # * An event processing thread that establishes consumers for message queues
  # * An error counter thread that manages the error counter
  # * A shutdown thread that listens for INT or TERM signals, which will trigger a graceful shutdown.
  # * The main thread is put to sleep until a shutdown is required.
  #
  # ==================
  # Registering Queues
  # ==================
  #
  # All active instances of all known EventObserver classes (which are assumed to be ActiveRecord instances) are
  # automatically loaded by the event processing thread, and their associated queues are bound. Note that queues
  # and associated routing key bindings are established at the time the instance is created or modified.
  # @see EventObserver.find_active_observers
  #
  # Each EventListener process creates an exclusive queue for monitoring the creation, modification, and destruction
  # of EventObserver instances, using ModelWatcher messages.
  #
  # ==============
  # Error Handling
  # ==============
  #
  # Whenever an uncaught exception is rescued from a consumer handling a message, it is logged and the error counter
  # is incremented. The error counter is reset periodically according to the value of +error_interval+.
  # If the total number of errors logged exceeds +error_limit+, the process is terminated immediately.
  # @see BunnyClient#subscribe()
  #
  # There are certain situations that may cause a Bunny exception to occur, such as a loss of network connection.
  # Whenever a Bunny exception is rescued in the event processing thread, the Bunny session is closed (canceling all
  # queue consumers), in addition to the error being counted, all Bunny channels are closed, and queues are
  # reinitialized.
  class EventListener
    include Logging

    attr_reader :error_count, :error_interval, :error_limit, :name, :queues, :events_exchange, :models_exchange, :status

    DEFAULT_ERROR_LIMIT    = 10
    DEFAULT_ERROR_INTERVAL = 3600

    DEFAULT_EVENTS_EXCHANGE = 'events'
    DEFAULT_MODELS_EXCHANGE = 'models'

    STATUS_INITIALIZE = :initialize
    STATUS_RUNNING    = :running
    STATUS_SHUTDOWN   = :shutdown

    # Initialize a new EventListener daemon instance
    # @param [Hash] options daemon options
    # @option options [Integer] :error_limit (10) maximum number of errors that are allowed to occur within error_interval
    #   before the process terminates
    # @option options [Integer] :error_interval (3600) time interval, in seconds, before the error counter is cleared
    # @option options [String] :events_exchange ('events') name of AMQP exchange used for listening to event messages
    # @option options [String] :models_exchange ('models') name of AMQP exchange used for listening to EventObserver
    #   instance create, update, and destroy messages
    # @option options [String] :name ("#{Rails.application.class.parent_name.downcase}-listener") daemon instance name.
    def initialize(options = {})
      default_options = {
          error_limit:     Isimud.listener_error_limit || DEFAULT_ERROR_LIMIT,
          error_interval:  DEFAULT_ERROR_INTERVAL,
          events_exchange: Isimud.events_exchange || DEFAULT_EVENTS_EXCHANGE,
          models_exchange: Isimud.model_watcher_exchange || DEFAULT_MODELS_EXCHANGE,
          name:            "#{Rails.application.class.parent_name.downcase}-listener"
      }
      options.reverse_merge!(default_options)
      @error_count         = 0
      @observers           = Hash.new
      @observed_models     = Set.new
      @error_limit         = options[:error_limit]
      @error_interval      = options[:error_interval]
      @events_exchange     = options[:events_exchange]
      @models_exchange     = options[:models_exchange]
      @name                = options[:name]
      @observer_mutex      = Thread::Mutex.new
      @error_counter_mutex = Thread::Mutex.new
      @status              = STATUS_INITIALIZE
    end

    # Run the daemon process. This creates the event, error counter, and shutdown threads
    def run
      bind_queues and return if test_env?
      start_shutdown_thread
      start_error_counter_thread
      client.on_exception do |e|
        count_error(e)
      end
      client.connect
      start_event_thread

      puts 'EventListener started. Hit Ctrl-C to exit'
      Thread.stop
      puts 'Main thread wakeup - exiting.'
      client.close
    end

    # Hook for setting up custom queues in your application. Override in your subclass.
    def bind_event_queues
    end

    # @private
    def bind_queues
      bind_observer_queues
      bind_event_queues
    end

    # @private
    def has_observer?(observer)
      @observers.has_key?(observer_key_for(observer.class, observer.id))
    end

    # @private
    def find_observer(klass, id)
      @observers[observer_key_for(klass, id)]
    end

    private

    def test_env?
      ['cucumber', 'test'].include?(Rails.env)
    end

    def bind_observer_queues
      Isimud::EventObserver.observed_models.each do |model_class|
        log "EventListener: registering observers for #{model_class}"
        register_observer_class(model_class)
        count = 0
        model_class.find_active_observers.each do |model|
          register_observer(model)
          count += 1
        end
        log "EventListener: registered #{count} observers for #{model_class}"
      end
      client.subscribe(observer_queue) do |payload|
        handle_observer_event(payload)
      end
    end

    def start_shutdown_thread
      shutdown_thread = Thread.new do
        Thread.stop # wait until we get a TERM or INT signal.
        log 'EventListener: shutdown requested.  Shutting down AMQP...', :info
        @status = STATUS_SHUTDOWN
        Thread.main.run
      end
      %w(SIGINT SIGTERM).each { |sig| trap(sig) { shutdown_thread.wakeup } }
    end

    def client
      Isimud.client
    end

    def initializing?
      status == STATUS_INITIALIZE
    end

    def running?
      status == STATUS_RUNNING
    end

    def shutdown?
      status == STATUS_SHUTDOWN
    end

    def start_event_thread
      Thread.new do
        log 'EventListener: starting event_thread', :info
        until shutdown? do
          begin
            bind_queues
            log 'EventListener: event_thread bind_queues finished', :info
            @status = STATUS_RUNNING
            Thread.stop
          rescue => e
            log "EventListener: error in event thread: #{e.message}\n  #{e.backtrace.join("\n  ")}", :warn
            count_error(e)
            @observer_queue = nil
            client.reset
          end
        end
      end
    end

    def count_error(exception)
      @error_counter_mutex.synchronize do
        @error_count += 1
        log "EventListener#count_error count = #{@error_count} limit=#{error_limit}", :warn
        if (@error_count >= error_limit)
          log 'EventListener: too many errors, exiting', :fatal
          @status = STATUS_SHUTDOWN
          Thread.main.run unless test_env?
        end
      end
    end

    def start_error_counter_thread
      log 'EventListener: starting error counter', :info
      @error_count = 0
      Thread.new do
        while true
          sleep(error_interval)
          @error_counter_mutex.synchronize do
            log('EventListener: resetting error counter') if @error_count > 0
            @error_count = 0
          end
        end
      end
    end

    def handle_observer_event(payload)
      event  = JSON.parse(payload).with_indifferent_access
      action = event[:action]
      log "EventListener: received observer model message: #{event.inspect}"
      if %w(update destroy).include?(action)
        unregister_observer(event[:type], event[:id])
      end
      if %w(create update).include?(action)
        observer = event[:type].constantize.find(event[:id])
        register_observer(observer) if observer.enable_listener?
      end
    end

    # Register the observer class watcher
    def register_observer_class(observer_class)
      @observer_mutex.synchronize do
        return if @observed_models.include?(observer_class)
        @observed_models << observer_class
        log "EventListener: registering observer class #{observer_class}"
        observer_queue.bind(models_exchange, routing_key: "#{Isimud.model_watcher_schema}.#{observer_class.base_class.name}.*")
      end
    end

    # Register an observer instance, and start listening for events on its associated queue.
    # Also ensure that we are listening for observer class update events
    def register_observer(observer)
      @observer_mutex.synchronize do
        log "EventListener: registering observer #{observer.class} #{observer.id}"
        @observers[observer_key_for(observer.class, observer.id)] = observer.observe_events(client)
      end
    end

    # Unregister an observer instance, and cancel consumption of messages. Any pre-fetched messages will be returned to the queue.
    def unregister_observer(observer_class, observer_id)
      @observer_mutex.synchronize do
        log "EventListener: un-registering observer #{observer_class} #{observer_id}"
        if (consumer = @observers.delete(observer_key_for(observer_class, observer_id)))
          consumer.cancel
        end
      end
    end

    # Create or return the observer queue which listens for ModelWatcher events
    def observer_queue
      @observer_queue ||= client.create_queue([name, 'listener', Socket.gethostname, Process.pid].join('.'),
                                              models_exchange,
                                              queue_options:     {exclusive: true},
                                              subscribe_options: {manual_ack: true})
    end

    def observer_key_for(type, id)
      [type.to_s, id.to_s].join(':')
    end
  end
end



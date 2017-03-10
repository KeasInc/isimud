[![Gem Version](https://badge.fury.io/rb/isimud.svg)](https://badge.fury.io/rb/isimud)

# Isimud: AMQP based Messaging and Event Processing Abstraction Component.

>Isimud is a minor god, the messenger of the god Enki in Sumerian mythology.
>He is readily identifiable by the fact that he possesses two faces looking in opposite directions.
>
>*Source: Wikipedia*

Isimud is an AMQP message publishing and consumption gem intended for Rails applications. It includes the following components:

* A [Bunny](http://rubybunny.info) based client interface for publishing and receiving messages using AMQP.
* A Model Watcher mixin for ActiveRecord that automatically sends messages whenever an ActiveRecord instance is created, modified, or destroyed.
* An Event Observer mixin for registering ActiveRecord models and instances with the EventListener for receiving messages.
* An Event Listener daemon process which manages queues and dispatches messages for Event Observers.
* A test client for mocking message publication, allowing synchronous delivery and processing of messages in unit tests.

# Installation

Add this line to your application's Gemfile:

    gem 'isimud'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install isimud
    
For Rails applications, use the following generators to create config and initializer files, respectively:

    $ rails g isimud:config
    $ rails g isimud:initializer
    
Customize the AMQP broker settings in the config/isimud.yml

# Usage

## Connecting to an AMQP Server

There are two supported conventions for specifying a RabbitMQ server (broker) in the configuration file:

### Using a URL

    server: amqp:port//user_name:password@host/vhost

### Using Separate Parameters:

    server:
        host:  hostname
        port:  15672
        user:  user_name
        pass:  password
        vhost: vhost

[Complete list of Bunny options available here](http://rubybunny.info/articles/connecting.html)

Isimud is designed to work with [RabbitMQ](http://www.rabbitmq.com).
Besides the standard AMQP 0.9.1 protocol, Isimud relies on Publishing Confirms (Acknowledgements), which
is a RabbitMQ specific extension to AMQP 0.9.1.

Note that Isimud does not automatically create exchanges. Make sure the exchange has been declared on the
message server, or you will get an exception. It is highly recommended to set the /durable/ parameter on the exchange
in order to prevent loss of messages due to failures.

Isimud uses [Bunny](http://rubybunny.info) to connect to RabbitMQ.

## Message Publication

Isimud publish messages to topic based exchanges. Each message is tagged with a routing key, allowing for multiple 
audiences to selectively receive messages. 

## Message Queues, Bindings, and Consumption

Isimud uses named, non-exclusive, durable queues to consume messages, with a configurable pre-fetch amount. 

There are two ways that message queues may be declared:

1. Using EventObserver instances. The EventObserver module allows an implementing class to define queues and bindings 
for each instance. 
  * The EventListener automatically establishes and manages queues for instances of each implementing class.
  * Each EventListener process maintains its own exclusive queue to automatically add or cancel consumers for
  EventObserver instances as they added, modified, or deleted.
2. Custom standalone queues. You may extend EventListener to declare individual queues not associated with a specific
object instance.

The EventListener process will automatically create and bind queues on startup if they do not already exist. This allows
for cold startup on a new AMQP broker.

### Message Delivery Information and Metadata

Each time that a message is retrieved from the queue, the following properties are set in the current thread:

| name | contents |
| ---- | -------- |
| isimud_queue_name | Name of the queue processing the thread |
| isimud_delivery_info | Message delivery information  *(Bunny::DeliveryInfo)*  |
| isimud_properties | Message properties metadata *(Bunny::MessageProperties)* |
 
### Exception Handling

If an uncaught instance of StandardError is raised during message processing, all exception handlers added to the
client are run in the order they were declared (see Client#on_exception). Any exceptions raised by the exception
handlers themselves are silently ignored.

You can configure the disposition of the message that triggered the exception using the configuration attribute 
Isimud.retry_failures as follows:

| Isimud.retry_failures | Behavior |
| :-------------------: | -------- |
| *false* | Never requeue messages (default) |
| *true* | Always requeue messages |
| *nil* | Conditionally re-queue messages based on exception handler return values |

When conditional re-queueing is enabled, requeue is determined based on the return value of all exception handlers, 
logically AND-ed. If the result is truthy, the message is re-queued. If the return value of any handler is falsey,
the message is not re-queued.

# Changes

## 1.4.7

* Simplify the AMQP queue lifecycle for EventObserver instances when they are updated.
  * Any previously existing queue for the instance is deleted on the broker.
  * When an EventListener process receives the EventObserver update message, it always recreates and rebinds the 
    queue for the instance.

## 1.4.6

* When consuming messages, use the channel setting from the delivery_info
* Explicitly set Bunny logger to the Isimud logger 
* Check if current channel is open before sending message ack 

## 1.4.3

* When an exception is raised during message processing, check status of channel before calling reject()
* Symbolize keys in options when initializing BunnyClient

## 1.4.2

* BunnyClient#publish now accepts additional metadata options
* Isimud::Event changes:
  * Added #timestamp property
  * Added #message_id for generating unique message IDs
  * message_id is now added to metadata when publishing 

## 1.4.1

* Enable conditional re-queuing of messages after an exception is raised (see *Exception Handling* above).
* Log messages for receipt and ack of messages downgraded to debug level.
* Force manual_ack mode for all queue subscriptions. 

## 1.3.9

* EventListener changes:
  * start_event_thread, dump exception backtrace to log
  * set log level to info or higher for all event thread messages

## 1.3.8

* In EventListener event thread, rescue all exceptions, not just Bunny ones.

## 1.3.7

* Change instance var 'status' inside the start event thread

## 1.3.6

* Don't include ModelWatcher attributes in event publish log message
* Include routing key in ModelWatcher event publish log message

## 1.3.5

* Added option to EventObserver#observe_events to recreate bindings for observer queues
* EventListener only create bindings and queues for EventObserver instances on initial startup
 
## 1.3.4

* Always recreate bindings for observer queues when EventListener starts the event thread.
* Cleaned up method signature on EventObserver#delete_queue so that a client may be passed to it. 

## 1.3.3

* Fixed handling of exceptions in TestClient
* Make EventListener#has_observer? public

## 1.3.1

* Add EventObserver#deactivate_observer to trigger queue deletion for an observer instance.

## 1.3.0

* Added a new method, EventListener#bind_event_queues() for registering custom event handlers. Override
  this method instead of bind_queues() to bind custom queues not handled by EventObserver instances.
* Add local host name to the EventListener observer queue to avoid possible collisions caused by processes on different
  hosts sharing the same PID.
* Added lots of documentation.

## 1.2.1

* Include attributes in ModelWatcher destroy message

## 1.2.0

* EventObserver#update_queue now always binds current routing keys. This ensures that when an enable_listener? changes
  state from false to true during an update, all bindings for the queue are established.
* Add EventObserver#activate_observer(), which creates and binds a queue for an observer instance on demand.
* Add declaration for Client#find_queue, and normalize the method signature for subclasses.

## 1.1.0

* Clients now support multiple exception handlers. Each call to Client#on_exception will add a new block to the
  exception handlers list

## 1.0.2

### Breaking Changes:

* EventObserver instances are now required to have the persistent attribute *exchange_routing_keys*. These are used to
  store the current value of routing keys assoicated with an instance. The queue associated with an EventObserver is
  now created and updated at the same time the EventObserver is updated, rather than relying on the EventListener to
  create it.
* EventObserver#observe_events now has only one parameter, the Isimud::Client instance. No queue bindings are done within
  this method.
* Client#bind has been refactored in order to separate concerns. A new method, #subscribe, is now used for subscribing
  to messages by linking a Proc.
* Client#create_queue no longer accepts a block parameter and does not subscribe to messages.
* Removed Client#rebind.

### Other Changes:

* TestClient::Queue now responds to bind() and unbind() in the same manner as Bunny::Queue.
* BunnyClient#create_queue now may be called without a block to instantiate an AMQP queue without subscribing to messages
* Added Client#rebind to change the exchange and routing keys for a durable named queue. 
* Changed BunnyClient#delete_queue to make it more reliable.
* EventListener now uses a shared, durable queue for monitoring events on modified EventObserver instances.

## 0.5.2

* Fixed regexp bug in TestClient affecting message delivery
* Add more logging for EventObserver binding

## 0.5.1

* Added Event#attributes

## 0.5.0

* Allow EventObserver classes to override the exchange for listening to events
* Corrected initialization of EventListener for handling defaults
* Create an explicit name for EventListener model queues for EventObserver instances
* Fixed a bug in EventObserver that caused ModelWatcher to not send update events appropriately when default columns are watched
* Moved requires for Isimud below config attribute declarations

## 0.4.10

* Corrected trap of INT and TERM signals
* Added error counter mutex and cleaned up logging
* Corrected race condition for registering EventObserver classes

## 0.4.5

* Fixed issues with exception handling

## 0.4.1

* Event now accepts an exchange option for publishing
* Added Isimud.events_exchange
* Cleaned up initializer template

## 0.4.0

* Event logging of published message now set to debug level
* Added EventListener and EventObserver
* Added new Client methods: create_queue, delete_queue. It is now possible to create queues with
  customized options (such as exclusive, non-durable queues).
* Clients can now be configured with an exception handler. This is used by EventListener to intercept exceptions raised
  during message handling by an observer.

## 0.3.7

* Added EventObserver mix-in
* Added accessors for queues and routing_keys to TestClient

## 0.3.6

* Reraise all exceptions in message processing block in BunnyClient#bind.

## 0.3.5

* Fixed deprecation on setting manual ack on Bunny queue subscriptions.

## 0.3.4

* Catch Timeout::Error in ModelWatcher.synchronize

## 0.3.1

* Tuning gargabe collector on ModelWatcher.synchronize

## 0.3.0

* Added rake task for manual synchronization using ModelWatcher

## 0.2.17

* Added guard on null #updated_at instances
* Added ModelWatcher#isimud_sync for manual synchronization

## 0.2.15

* Changed Event#send to Event#publish, to avoid overloading Ruby.

## 0.2.13

* Add :omit_parameters option to Event#as_json

## 0.2.12

* Demodulize ActiveRecord model name when setting ModelWatcher event type

## 0.2.10

* Added Isimud.retry_failures
* Isimud::ModelWatcher now includes :created_at and :updated_at columns by default
* Added Isimud::Client.connected?
* Avoid connecting to database when Isimud::ModelWatcher.watch_attributes is called

## 0.2.4

* Add Isimud::ModelWatcher#isimud_synchronize? to allow conditional synchronization. Override to activate.

## 0.2.2

* Add enable_model_watcher configuration parameter (default is true)

## 0.2.0

* Added Isimud::Event
* Extracted Isimud::Client#log into Isimud::Logging module

## 0.1.4

* Don't reject messages when exception is raised in bind block

## 0.1.3

* Upgrade bunny gem requirement to 1.3.x
* Fixed message acknowledgements
* Added log_level configuration parameter (default is :debug)

## 0.1.2

* Reject message with requeue when an exception is raised during processing

## 0.1.1

* Enable channel confirmations for message publication

## 0.1.0

* ModelWatcher mix-in for ActiveRecord, sends events on instance changes
* Initializer generator for Rails

## Contributing

1. Fork it ( https://github.com/KeasInc/isimud/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

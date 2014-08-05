# Isimud

Messaging abstraction layer for AMQP and testing.

## Installation

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

## Usage

### Connecting to an AMQP server

TBD

### Message publication

TBD

### Message binding and consumption

TBD

## Changes

### 0.1.5

* Added Isimud::Event
* Extracted Isimud::Client#log into Isimud::Logging module

### 0.1.4

* Don't reject messages when exception is raised in bind block

### 0.1.3

* Upgrade bunny gem requirement to 1.3.x
* Fixed message acknowledgements
* Added log_level configuration parameter (default is :debug)

### 0.1.2

* Reject message with requeue when an exception is raised during processing

### 0.1.1

* Enable channel confirmations for message publication

### 0.1.0

* ModelWatcher mix-in for ActiveRecord, sends events on instance changes
* Initializer generator for Rails

### 0.0.8 (first working version)

* Don't clear the queues when reconnecting TestClient


## Contributing

1. Fork it ( https://github.com/[my-github-username]/isimud/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

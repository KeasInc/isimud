# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'isimud/version'

Gem::Specification.new do |spec|
  spec.name          = 'isimud'
  spec.version       = Isimud::VERSION
  spec.authors       = ['George Feil', 'Brian Jenkins']
  spec.email         = %w{george.feil@keas.com bonkydog@bonkydog.com}
  spec.summary       = %q{AMQP Messaging and Event Processing}
  spec.description   = <<-EOT
Isimud is an AMQP message publishing and consumption gem that is intended for managing asynchronous event queues in Rails applications. It consists of the following components:

* A [Bunny](http://rubybunny.info) based client interface for publishing and receiving messages using AMQP.
* A test client which mocks most client operations and allows for synchronous delivery and processing of messages for unit tests.
* A Model Watcher mixin for ActiveRecord that automatically sends messages whenever an ActiveRecord instance is created, modified, or destroyed.
* An Event Observer mixin for registering ActiveRecord models and instances with the EventListener for receiving messages.
* An Event Listener daemon process which manages queues and dispatches messages for Event Observers.
EOT
  spec.homepage      = 'https://github.com/KeasInc/isimud'
  spec.license       = 'MITNFA'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 4.1.4'
  spec.add_dependency 'activesupport', '>= 4.1.4'
  spec.add_dependency 'bunny', '>= 1.6.0'
  spec.add_dependency 'chronic_duration', '>= 0.10.6'
end

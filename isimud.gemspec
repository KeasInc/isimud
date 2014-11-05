# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'isimud/version'

Gem::Specification.new do |spec|
  spec.name          = 'isimud'
  spec.version       = Isimud::VERSION
  spec.authors       = ['George Feil', 'Brian Jenkins']
  spec.email         = %w{george.feil@keas.com bonkydog@bonkydog.com}
  spec.summary       = %q{AMQP Messaging for Events and ActiveRecord changes}
  spec.description   = %q{}
  spec.homepage      = ''
  spec.license       = "Copyright (C) 2014 Keas -- All rights reserved"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 3.2.17'
  spec.add_dependency 'activesupport', '>= 3.2.17'
  spec.add_dependency 'bunny', '>= 1.6.0'
  spec.add_dependency 'chronic_duration', '>= 0.10.6'
end

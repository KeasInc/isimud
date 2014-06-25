# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'isimud/version'

Gem::Specification.new do |spec|
  spec.name          = 'isimud'
  spec.version       = Isimud::VERSION
  spec.authors       = ['Brian Jenkins']
  spec.email         = ['bonkydog@bonkydog.com']
  spec.summary       = %q{AMQP update logging for ActiveRecord models.}
  spec.description   = %q{}
  spec.homepage      = ''
  spec.license       = 'Copyright Keas -- All rights reserved'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', '3.2.17'
  spec.add_runtime_dependency 'bunny', '0.9.0pre7'
  spec.add_runtime_dependency 'mysql2', '~> 0.3.15'

end

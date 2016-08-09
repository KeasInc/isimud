# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'isimud/version'

Gem::Specification.new do |spec|
  spec.name        = 'isimud'
  spec.version     = Isimud::VERSION
  spec.authors     = ['George Feil', 'Brian Jenkins']
  spec.email       = %w{george.feil@keas.com bonkydog@bonkydog.com}
  spec.summary     = %q{AMQP Messaging and Event Processing}
  spec.description = <<-EOT
Isimud is an AMQP message publishing and consumption gem intended for Rails applications. You can use it to define
message consumption queues for ActiveRecord instances, or synchronize model updates between processes. It also provides
an event listener background process for managing queues that consume messages.
  EOT
  spec.homepage    = 'https://github.com/KeasInc/isimud'
  spec.license     = 'MITNFA'
  spec.cert_chain  = ['certs/gfeil.pem']
  spec.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 4.1.4'
  spec.add_dependency 'activesupport', '>= 4.1.4'
  spec.add_dependency 'bunny', '>= 1.6.0'
  spec.add_dependency 'chronic_duration', '>= 0.10.6'
end

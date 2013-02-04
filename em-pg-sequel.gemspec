# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "em-pg-sequel"
  gem.version       = "0.0.1"
  gem.authors       = ["Petr Yanovich"]
  gem.email         = ["fl00r@yandex.ru"]
  gem.description   = %q{Sequel adapter for ruby-em-pg-client}
  gem.summary       = %q{Sequel adapter for ruby-em-pg-client}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "pg"
  gem.add_dependency "em-pg-client"

  gem.add_development_dependency "em-synchrony"
end

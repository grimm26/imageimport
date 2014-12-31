# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'imageimport/version'

Gem::Specification.new do |spec|
  spec.name          = 'imageimport'
  spec.version       = ImageImport::VERSION
  spec.authors       = ['Mark Keisler']
  spec.email         = ['grimm26@gmail.com']
  spec.summary       = 'Watch a directory for photos to import.'
  spec.description   = 'Use inotify to watch a directory to import new images into a directory structure based on date/time the photo was taken.'
  spec.homepage      = 'https://github.com/grimm26/imageimport'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.0'

  spec.add_development_dependency 'bundler', '~> 1'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rake', '~> 10'
  spec.add_development_dependency 'rspec', '~>2'
  spec.add_development_dependency 'pry'
  # spec.add_development_dependency 'pry-byebug'
  spec.add_dependency 'rb-inotify', '~> 0.9'
  spec.add_dependency 'ruby-filemagic', '~> 0.5'
  spec.add_dependency 'exifr', '~> 1'
  spec.add_dependency 'daemons', '~> 1'
end

# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rapidshare-ext/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'rapidshare-ext'
  gem.version       = Rapidshare::Ext::VERSION
  gem.authors       = %w{odiszapc}
  gem.email         = %w{odiszapc@gmail.com}
  gem.description   = %q{Extends the original rapidshare gem with a set of handy features}
  gem.summary       = %q{Makes your interactions with Rapidshare API more pleasant by providing new handy features: creating/moving/deleting files/folders in a user friendly way, upload files, etc}
  gem.homepage      = 'http://github.com/odiszapc/rapidshare-ext'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = %w{lib}


  gem.add_dependency('rest-client', '~> 1.6.7')

  gem.add_development_dependency('test-unit', '~> 2.5.4')
  gem.add_development_dependency('shoulda', '~> 3.3.2')
  gem.add_development_dependency('simplecov', '~> 0.7.1')
  gem.add_development_dependency('fakeweb', '~> 1.3.0')
  gem.add_development_dependency('mocha', '~> 0.13.2')
  gem.add_development_dependency('rake', '~> 10.0.3')
end

# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rapidshare-ext/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "rapidshare-ext"
  gem.version       = Rapidshare::Ext::VERSION
  gem.authors       = ["odiszapc"]
  gem.email         = ["odiszapc@gmail.com"]
  gem.description   = %q{Extends the original rapidshare gem with a set of handy features}
  gem.summary       = %q{Makes your interactions with Rapidshare API more pleasant by providing new handy features: creating/moving/deleting files/folders in a user friendly way, upload files, etc}
  gem.homepage      = "http://github.com/odiszapc/rapidshare-ext"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]


  gem.add_dependency('rapidshare', '~> 0.5.3')
  gem.add_dependency('rest-client', '~> 1.6.7')

  gem.add_development_dependency('test-unit')
  gem.add_development_dependency('shoulda')
  gem.add_development_dependency('simplecov')
  gem.add_development_dependency('fakeweb')
end

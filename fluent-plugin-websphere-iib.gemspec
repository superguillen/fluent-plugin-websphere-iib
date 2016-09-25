# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "fluent-plugin-websphere-iib"
  gem.description = "Input plugin for websphere Integration Bus syslog"
  gem.homepage    = "https://github.com/superguillen/fluent-plugin-websphere-iib"
  gem.summary     = gem.description
  gem.version     = "1.0"
  gem.authors     = ["superguillen"]
  gem.email       = "superguillen.public@gmail.com"
  gem.has_rdoc    = false
  gem.license     = 'MIT'
  gem.files       = Dir['Rakefile', '{bin,lib,man,test,spec}/**/*', 'README*', 'LICENSE*']
  gem.require_paths = ['lib']

  gem.add_dependency "fluentd", "~> 0.10.45"
  gem.add_development_dependency "rake", ">= 0.9.2"
end

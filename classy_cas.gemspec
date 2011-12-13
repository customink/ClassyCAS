# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
  
Gem::Specification.new do |s|
  s.name        = "classy_cas"
  s.version     = "0.9.3"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Andrew O'Brien", "Tim Case", "Nick Browning"]
  s.email       = ["andrew@econify.com"]
  s.homepage    = "https://rubygems.org/gems/classy_cas"
  s.summary     = "A Central Authentication Service server built on Sinatra and Redis"
  s.description = "ClassyCAS provides private, centralized, cross-domain, platform-agnostic centralized authentication than can hook in with modern Ruby authentication systems."

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency('sinatra', '1.3.1')
  s.add_dependency('redis', '~>2.0')
  s.add_dependency('addressable', '~>2.2.2')
  s.add_dependency('nokogiri', '~>1.4.4')
  s.add_dependency('rack', '~>1.3.4')
  s.add_dependency('rack-flash')
  if RUBY_VERSION < "1.9"
    s.add_dependency('backports')
    s.add_dependency('SystemTimer', "~>1.2")
  end
  
  s.add_dependency('warden')
  
  s.files        = Dir.glob("{lib,public}/**/*") + %w(README.textile config.ru)
  s.require_path = 'lib'
end



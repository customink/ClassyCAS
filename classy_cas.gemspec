# -*- encoding: utf-8 -*-
require File.expand_path('../lib/classy_cas/version', __FILE__)

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "classy_cas"
  s.version     = ClassyCAS::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Andrew O'Brien", "Tim Case", "Nick Browning", "Derek Lindahl (CustomInk)"]
  s.email       = ["andrew@econify.com"]
  s.homepage    = "https://rubygems.org/gems/classy_cas"
  s.summary     = "A Central Authentication Service server built on Sinatra and Redis"
  s.description = "ClassyCAS provides private, centralized, cross-domain, platform-agnostic centralized authentication than can hook in with modern Ruby authentication systems."

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency 'addressable',               '~> 2.2.6'
  s.add_dependency 'nokogiri',                  '~> 1.5.0'
  s.add_dependency 'rack',                      '~> 1.4.1'
  s.add_dependency 'sinatra-flash',             '~> 0.3.0'
  s.add_dependency 'redis',                     '~> 2.2.2'
  s.add_dependency 'sinatra',                   '~> 1.3.2'
  s.add_dependency 'warden',                    '~> 1.1.0'

  s.add_development_dependency 'shotgun',       '~> 0.9'
  s.add_development_dependency 'shoulda',       '~> 2.11.3'
  s.add_development_dependency 'webrat',        '~> 0.7.3'
  s.add_development_dependency 'ruby-debug19',  '~> 0.11.6'

  s.files        = Dir.glob("{lib,public}/**/*") + %w(README.textile config.ru)
  s.require_path = 'lib'
end
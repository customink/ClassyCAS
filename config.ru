require 'rubygems'
require 'bundler'
Bundler.require :default, :development
require_relative 'classy_cas'

run ClassyCAS::Server

# Main include file for the tem_multi_updater Rubygem.
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Massachusetts Institute of Technology
# License:: MIT

# Gem requirements.
require 'rubygems'
require 'smartcard'
require 'tem_ruby'
require 'tem_multi_proxy'

# :nodoc: namespace
module Tem  
end

# The files making up the gem.
require 'tem_multi_updater/updater.rb'

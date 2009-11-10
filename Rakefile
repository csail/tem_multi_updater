# Rakefile for the tem_multi_updater gem.
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Massachusetts Institute of Technology
# License:: MIT

require 'rubygems'
gem 'echoe'
require 'echoe'

Echoe.new('tem_multi_updater') do |p|
  p.project = 'tem'  # rubyforge project
  p.docs_host = "costan@rubyforge.org:/var/www/gforge-projects/tem/rdoc/"
  
  p.author = 'Victor Costan'
  p.email = 'victor@costan.us'
  p.summary = 'Updates the firmware on all TEMs connected to a tem_multi_proxy.'
  p.url = 'http://tem.rubyforge.org'
  p.dependencies = ['smartcard >=0.4.7',
                    'tem_multi_proxy >=0.2.5',
                    'tem_ruby >=0.12.0']
  p.development_dependencies = ['echoe >=3.2',
                                'flexmock >=0.8.6']
  
  p.need_tar_gz = !Gem.win_platform?
  p.need_zip = !Gem.win_platform?
  p.rdoc_pattern = /^(lib|bin|tasks|ext)|^BUILD|^README|^CHANGELOG|^TODO|^LICENSE|^COPYING$/  
end

if $0 == __FILE__
  Rake.application = Rake::Application.new
  Rake.application.run
end

#!/usr/bin/env ruby

require 'daemons'

Daemons.run('/usr/local/bin/watch_and_import.rb', {:dir_mode => :normal, dir: '/var/tmp'})

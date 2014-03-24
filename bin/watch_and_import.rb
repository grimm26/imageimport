#!/usr/bin/env ruby
#
require 'imageimport'
require 'optparse'
require 'logger'
require 'daemons'


Daemons.run_proc(File.basename(__FILE__),{:dir_mode => :normal, dir: '/var/tmp' }) do

  loglevels = { 'DEBUG'   => Logger::DEBUG,
                'INFO'    => Logger::INFO,
                'WARN'    => Logger::WARN,
                'ERROR'   => Logger::ERROR,
                'FATAL'   => Logger::FATAL,
                'UNKNOWN' => Logger::UNKNOWN
              }

  # Get rid of args before '--' that are meant for Daemons
  sep_idx = ARGV.find_index('--')
  unless sep_idx.nil?
    ARGV.slice!(0..sep_idx)
  end

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("-w DIRECTORY","--watchdir", "What directory to watch for incoming jpegs.") do |dir|
      if Dir.exists?(dir)
        options[:watchdir] = dir
      else
        opts.abort "Supplied watchdir, #{dir}, is not a valid directory."
      end
    end

    opts.on("-d DIRECTORY","--destination", "The top of the directorty in which to place imported images.") do |dir|
      if Dir.exists?(dir)
        options[:destination] = dir
      else
        opts.abort "Supplied destination, #{dir}, is not a valid directory."
      end
    end

    options[:loglevel] = loglevels['INFO']
    opts.on("--loglevel LEVEL", loglevels,  "Logging level (DEBUG, INFO, WARN, ERROR, FATAL, UNKNOWN).") do |level|
      options[:loglevel] = level
    end

    options[:logfile] = STDERR
    opts.on("--logfile FILE", "File or filehandle to log to.") do |file|
      options[:logfile] = file
    end

  end.parse!

  begin
    log = Logger.new(options[:logfile],3,100 * 1024 * 1024)
    log.level = options[:loglevel]
    log.datetime_format = '%Y-%m-%d %H:%M:%S'
  rescue SystemCallError => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.inspect
  end

  ImageImport::Watch.new(watch: options[:watchdir], destination: options[:destination], logger: log)
end

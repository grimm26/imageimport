#!/usr/bin/ruby 
#
require_relative 'lib/watchdir'
require 'optparse'
require 'logger'

loglevels = { 'DEBUG'   => Logger::DEBUG,
              'INFO'    => Logger::INFO,
              'WARN'    => Logger::WARN,
              'ERROR'   => Logger::ERROR,
              'FATAL'   => Logger::FATAL,
              'UNKNOWN' => Logger::UNKNOWN
            }

options = {}
begin
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("-w DIRECTORY","--watchdir", "What directory to watch for incoming jpegs.") do |dir|
      options[:watchdir] = dir
    end

    opts.on("-d DIRECTORY","--destination", "The top of the directorty in which to place imported images.") do |dir|
      options[:destination] = dir
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
rescue Exception => e
  STDERR.puts e.message
  STDERR.puts e.backtrace.inspect
end

begin
  log = Logger.new(options[:logfile],3,100 * 1024 * 1024)
  log.level = options[:loglevel]
  log.datetime_format = '%Y-%m-%d %H:%M:%S'
rescue SystemCallError => e
  STDERR.puts e.message
  STDERR.puts e.backtrace.inspect
end

ImageWatch.new(watch: options[:watchdir], destination: options[:destination], logger: log)

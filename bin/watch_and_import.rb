#!/usr/bin/env ruby
#
require 'imageimport'
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
optparse = OptionParser.new do |opts|
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
end

optparse.parse
if options[:watchdir].nil? || options[:destination].nil?
  optparse.abort "Both --watchdir and --destination must be supplied.\n\n#{optparse.help}"
end

begin
  log = Logger.new(options[:logfile],3,100 * 1024 * 1024)
  log.level = options[:loglevel]
  log.datetime_format = '%Y-%m-%d %H:%M:%S'
rescue SystemCallError => e
  STDERR.puts e.message
  STDERR.puts e.backtrace.inspect
end

ImageImport::Watch.new(watch: options[:watchdir], destination: options[:destination], logger: log)

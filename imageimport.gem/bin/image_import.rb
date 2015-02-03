#!/usr/bin/env ruby
#
# TODO: Make this file (or most of it) its own class,
#   perhaps a child of Logger::Application.
# TODO: Log start and finish of process.
require 'imageimport'
require 'optparse'
require 'ostruct'
require 'logger'
require 'daemons'

loglevels = {
  'DEBUG'   => Logger::DEBUG,
  'INFO'    => Logger::INFO,
  'WARN'    => Logger::WARN,
  'ERROR'   => Logger::ERROR,
  'FATAL'   => Logger::FATAL,
  'UNKNOWN' => Logger::UNKNOWN
}

options = OpenStruct.new(
  daemonize:   false,
  stop_daemon: false,
  flush:       false,
  watchdir:    nil,
  destination: nil,
  group:       Process.egid,
  delay:       0,
  loglevel:    loglevels['INFO'],
  logfile:     STDERR
)

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on('-w DIRECTORY', '--watchdir', 'What directory to watch for incoming jpegs.') do |dir|
    if Dir.exist?(dir)
      options.watchdir = dir
    else
      opts.abort "Supplied watchdir, #{dir}, is not a valid directory."
    end
  end

  opts.on('-d DIRECTORY', '--destination', 'The top of the directorty in which to place imported images.') do |dir|
    if Dir.exist?(dir)
      options.destination = dir
    else
      opts.abort "Supplied destination, #{dir}, is not a valid directory."
    end
  end

  opts.on('--delay SECONDS', 'Number of seconds to delay after a file is noticed.') do |seconds|
    options.delay = seconds.to_i
  end

  opts.on('--flush', 'First flush the existing files in the watch directory.') do |tf|
    options.flush = tf
  end

  opts.on('--loglevel LEVEL', loglevels,  'Logging level (DEBUG, INFO, WARN, ERROR, FATAL, UNKNOWN).') do |level|
    options.loglevel = level
  end

  opts.on('--logfile FILE', 'File or filehandle to log to.') do |file|
    options.logfile = file
  end

  opts.on('--group GROUP', 'Group to own files.') do |group|
    options.group = group
  end

  opts.on('--[no-]daemonize', 'Run as a daemon') do |tf|
    options.daemonize = tf
  end

  opts.on('--stop-daemon', 'Stop a running daemon') do |tf|
    options.stop_daemon = tf
  end

  opts.on('--version', 'What version is this?') do
    puts "ImageImport v#{ImageImport::VERSION}"
    exit
  end
end

begin
  optparse.parse!
rescue SystemExit
  abort
rescue OptionParser::ParseError => e
  optparse.abort "#{e.message}\n\n#{optparse.help}"
end

if options.stop_daemon
  Daemons.run_proc(File.basename(__FILE__), dir_mode: :normal, dir: '/var/tmp', ARGV: ['stop'], ontop: false) do
    sleep(1)
  end
  exit 1
end

if options.watchdir.nil? || options.destination.nil?
  optparse.abort "Both --watchdir and --destination must be supplied.\n\n#{optparse.help}"
end

if options.daemonize && options.logfile == STDERR
  STDERR.puts "Logfile automatically set to /var/tmp/#{File.basename(__FILE__)}.log"
  options.logfile = "/var/tmp/#{File.basename(__FILE__)}.log"
end

# Open up log
begin
  log = Logger.new(options.logfile, 3, 100 * 1024 * 1024)
  log.level = options.loglevel
  log.datetime_format = '%Y-%m-%d %H:%M:%S'
  log.info('Process start.')
rescue SystemCallError => e
  STDERR.puts e.message
  STDERR.puts e.backtrace.inspect
end

# Set up ARGV to be fed to run_proc based on whether we want to run in the background or not
d_hash = { dir_mode: :normal, dir: '/var/tmp', ontop: !options.daemonize }
if options.daemonize
  d_hash[:ARGV] = ['start']
else
  d_hash[:ARGV] = ['run']
end

begin
  if options.flush
    log.info("Flushing #{options.watchdir}...")
    Dir.entries(options.watchdir).select { |f| f =~ /^\w\.jpg|^\w\.jpeg$/i }.each do |jpg|
      ImageImport::JpegByDate.new(
        source:      File.join(options.watchdir, jpg),
        destination: options.destination,
        logger:      log,
        group:       options.group
      )
    end
  end
  Daemons.run_proc(File.basename(__FILE__), d_hash) do
    ImageImport::Watch.new(
      watch:       options.watchdir,
      destination: options.destination,
      logger:      log,
      delay:       options.delay,
      group:       options.group
    )
  end
rescue SystemCallError => e
  STDERR.puts e.message
  STDERR.puts e.backtrace.inspect
  exit 1
end

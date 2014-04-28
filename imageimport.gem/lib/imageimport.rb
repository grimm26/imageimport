require "imageimport/version"
require "imageimport/jpeg_by_date"
require 'rb-inotify'
require 'logger'
require 'filemagic'
require 'exifr/jpeg'
require 'date'


module ImageImport
  class Watch
    include EXIFR

    def initialize(watch: nil,destination: nil, logger: Logger.new(STDERR))
      raise SystemCallError,"Error accessing watchdir <<#{watch}>>" unless File.directory?(watch)
      raise SystemCallError,"Error accessing destination <<#{destination}>>" unless File.directory?(destination)
      File.umask(0002)
      @logger = logger
      @destination = destination
      logger.info("Initializing ImageWatch on #{watch}.  Destination: #{destination}")
      notifier = INotify::Notifier.new
      notifier.watch(watch, :moved_to, :close_write) { |event| processInotifyEvent(event) }
      notifier.run
    end

    private
    def processInotifyEvent(event)
      filepath = event.absolute_name
      @logger.debug("Processing #{filepath}...")
      JpegByDate.importFile(filepath: filepath, destination: @destination, logger: @logger)
    end
  end
end

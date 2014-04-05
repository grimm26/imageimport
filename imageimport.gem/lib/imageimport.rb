require "imageimport/version"
require 'rb-inotify'
require 'logger'
require 'filemagic'
require 'exifr/jpeg'
require 'date'


module ImageImport
  class Watch
    include EXIFR
    attr_accessor :logger, :destintation

    def initialize(watch: nil,destination: nil, logger: Logger.new(STDERR))
      raise "Error accessing watchdir <<#{watch}>>" unless File.directory?(watch)
      raise "Error accessing destination <<#{destination}>>" unless File.directory?(destination)
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
      logger.debug("Processing #{filepath}...")
      if FileMagic.open(:mime_type) { |fm| fm.file(filepath) } == 'image/jpeg'
        logger.info("Found new jpeg: #{filepath}")
        dt = JPEG.new(filepath).date_time
        if dt == nil
          logger.info("No date info in #{filepath}. Skipping.")
        else
          dest_dir  = File.join(destination,dt.strftime("%Y_%m_%d"))
          dest_file = File.join(dest_dir,dt.strftime("%Y_%m_%d-%H_%M_%S") + ".jpg")

          if File.exist?(dest_file)
              logger.info("Skipping duplicate #{dest_file}")
            begin
              File.delete(filepath)
            rescue Exception => e
              logger.warn("Failed removal of #{filepath}: #{e.message}")
            end
          else
            begin
              logger.info("Moving #{filepath} to #{dest_file}")
              unless Dir.exist?(dest_dir)
                logger.debug("Creating new destination directory #{dest_dir}")
                Dir.mkdir(dest_dir)
                File.chown(nil,444,dest_dir)
                File.chmod(02775,dest_dir)
              end
              File.rename(filepath,dest_file)
              File.chmod(0664,dest_file)
              File.chown(nil,444,dest_file)
            rescue SystemCallError => e
              logger.error("Error processing #{dest_file}: #{e.message} #{e.backtrace[0]}")
            end
          end
        end
      end
    end
  end
end

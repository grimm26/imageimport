require 'rb-inotify'
require 'logger'

module ImageImport
  # Set up a watch of a directory
  class Watch
    def initialize(
                    watch:       nil,
                    destination: nil,
                    logger:      Logger.new(STDERR),
                    delay:       0,
                    group:       Process.egid
                  )
      fail SystemCallError, "Error accessing watchdir <<#{watch}>>" unless File.directory?(watch)
      fail SystemCallError, "Error accessing destination <<#{destination}>>" unless File.directory?(destination)
      File.umask(0002)
      @logger      = logger
      @destination = destination
      @group       = group
      logger.info("Initializing ImageWatch on #{watch}.  Destination: #{destination}")
      notifier = INotify::Notifier.new
      threads = notifier.watch(watch, :moved_to, :close_write) do |event|
        Thread.new(event) do |t_event|
          sleep(delay)
          process_inotify_event(t_event)
        end
      end
      notifier.run
      threads.each(&:join)
    end

    private

    def process_inotify_event(event)
      filepath = event.absolute_name
      return if event.name =~ /^\./
      @logger.debug("Processing #{filepath}...")
      JpegByDate.new(source: filepath, destination: @destination, logger: @logger, group: @group)
    end
  end
end

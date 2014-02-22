require 'rb-inotify'
require 'filemagic'
require 'exifr/jpeg'
require 'date'

class ImageWatch
  include EXIFR

  def initialize(watch,destination)
    raise "Error accessing watchdir <<#{watch}>>" unless File.directory?(watch)
    raise "Error accessing destination <<#{destination}>>" unless File.directory?(destination)
    @destination = destination
    @notifier = INotify::Notifier.new
    @notifier.watch(watch, :moved_to, :close_write) { |event| processInotifyEvent(event) }
    @notifier.run
  end

  private
  def processInotifyEvent(event)
    filepath = event.absolute_name
    if FileMagic.open(:mime_type) { |fm| fm.file(filepath) } == 'image/jpeg'
      #dt = DateTime.parse(JPEG.new(filepath).date_time)
      dt = JPEG.new(filepath).date_time
      if dt == nil
        STDERR.puts "No date info in #{filepath}"
      else
        ts = dt.strftime("%Y_%m_%d-%H_%M_%S")
        puts "Found jpeg: #{filepath}, #{ts}"
        dest_dir  = File.join(@destination,dt.strftime("%Y_%m_%d"))
        dest_file = File.join(dest_dir,dt.strftime("%Y_%m_%d-%H_%M_%S") + ".jpg")

        puts "Moving #{filepath} to #{dest_file}"
      end
    end
  end
end

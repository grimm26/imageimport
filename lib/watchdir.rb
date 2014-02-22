require 'rb-inotify'
require 'filemagic'
require 'exifr/jpeg'

class ImageWatch
  include EXIFR

  def initialize(dir)
    @notifier = INotify::Notifier.new
    raise "Error accessing #{dir}" unless File.directory?(dir)
    @notifier.watch(dir, :moved_to, :close_write) { |event| processInotifyEvent(event) }
    @notifier.run
  end

  private
  def processInotifyEvent(event)
    filepath = event.absolute_name
    if FileMagic.open(:mime_type) { |fm| fm.file(filepath) } == 'image/jpeg'
      dt = JPEG.new(filepath).date_time
      puts "Found jpeg: #{filepath}, #{dt}"
    end
  end
end

require 'rb-inotify'
require 'filemagic'
require 'exifr/jpeg'
require 'date'

class ImageWatch
  include EXIFR

  def initialize(watch: nil,destination: nil)
    raise "Error accessing watchdir <<#{watch}>>" unless File.directory?(watch)
    raise "Error accessing destination <<#{destination}>>" unless File.directory?(destination)
    File.umask(0002)
    @destination = destination
    @notifier = INotify::Notifier.new
    @notifier.watch(watch, :moved_to, :close_write) { |event| processInotifyEvent(event) }
    @notifier.run
  end

  private
  def processInotifyEvent(event)
    filepath = event.absolute_name
    if FileMagic.open(:mime_type) { |fm| fm.file(filepath) } == 'image/jpeg'
      dt = JPEG.new(filepath).date_time
      if dt == nil
        STDERR.puts "No date info in #{filepath}. Skipping."
      else
        ts = dt.strftime("%Y_%m_%d-%H_%M_%S")
        dest_dir  = File.join(@destination,dt.strftime("%Y_%m_%d"))
        dest_file = File.join(dest_dir,dt.strftime("%Y_%m_%d-%H_%M_%S") + ".jpg")

        if File.exist?(dest_file)
          STDERR.puts "Skipping duplicate #{destfile}"
          begin
            File.delete(filepath)
          rescue Exception => e
            STDERR.print "Failed removal of #{filepath}: "
            STDERR.puts e.message
          end
        else
          begin
            STDERR.puts "Moving #{filepath} to #{dest_file}"
            unless Dir.exist?(dest_dir)
              Dir.mkdir(dest_dir)
              File.chown(nil,444,dest_dir)
              File.chmod(02775,dest_dir)
            end
            File.rename(filepath,dest_file)
            File.chmod(0664,dest_file)
            File.chown(nil,444,dest_file)
          rescue SystemCallError => e
            STDERR.print "Error processing #{dest_file}: "
            STDERR.puts e.message
          end
        end
      end
    end
  end
end

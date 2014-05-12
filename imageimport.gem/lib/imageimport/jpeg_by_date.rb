require 'logger'
require 'filemagic'
require 'exifr/jpeg'
require 'date'


module ImageImport
  class JpegByDate
    include EXIFR

    def self.importFile(filepath: filepath,destination: destination, logger: logger)
      begin
        if FileMagic.open(:mime_type) { |fm| fm.file(filepath) } == 'image/jpeg'
          logger.info("Found new jpeg: #{filepath}")
          dt = JPEG.new(filepath).date_time
          if dt == nil
            logger.info("No date info in #{filepath}. Dumping into unsorted.")
            unsorted = File.join(destination,'unsorted')
            unless Dir.exist?(unsorted)
              logger.debug("Creating new destination directory #{unsorted}")
              Dir.mkdir(unsorted)
              File.chown(nil,444,unsorted)
              File.chmod(02775,unsorted)
            end
            dest_file = File.join(unsorted,File.basename(filepath))
            File.rename(filepath,dest_file)
            File.chmod(0664,dest_file)
            File.chown(nil,444,dest_file)
          else
            dest_dir  = File.join(destination,dt.strftime("%Y_%m_%d"))
            dest_file = File.join(dest_dir,dt.strftime("%Y_%m_%d-%H_%M_%S") + ".jpg")

            if File.exist?(dest_file)
              logger.info("Skipping duplicate #{dest_file}")
              File.delete(filepath)
              logger.warn("Failed removal of #{filepath}")
            else
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
            end
          end
        end
      rescue SystemCallError => e
        logger.error("Error processing #{dest_file}: #{e.message} #{e.backtrace[0]}")
      end
    end
  end 
end

require 'logger'
require 'filemagic'
require 'fileutils'
require 'exifr/jpeg'
require 'date'
require 'etc'

module ImageImport
  # Methods to sort jpegs by date.
  class JpegByDate
    include EXIFR

    def initialize(
                    source:      nil,
                    destination: nil,
                    logger:      Logger.new(STDERR),
                    group:       Process.egid
                  )
      @logger      = logger
      @group       = (group.is_a?(Integer) && group) || Etc.getgrnam(group).gid

      @logger.debug("Starting process for #{source}. Group: #{group}.")
      process_file(source: source, destination: destination)
    end

    def process_file(source: nil, destination: nil)
      if FileMagic.open(:mime_type) { |fm| fm.file(source) } == 'image/jpeg'
        @logger.info("Found new jpeg: #{source}")
        dt = JPEG.new(source).date_time
        if dt.nil?
          @logger.info("No date info in #{source}. Dumping into unsorted.")
          unsorted = File.join(destination, 'unsorted')
          ensure_dir unsorted
          dest_file = File.join(unsorted, File.basename(source))
          import_file(source: source, dest: dest_file)
        else
          @logger.debug("Date info found in #{source}.")
          dest_dir  = File.join(destination, dt.strftime('%Y_%m_%d'))
          dest_file = File.join(dest_dir, dt.strftime('%Y_%m_%d-%H_%M_%S') + '.jpg')

          if File.exist?(dest_file)
            @logger.info("Skipping duplicate #{dest_file}")
            File.delete(source)
          else
            ensure_dir dest_dir
            import_file(source: source, dest: dest_file)
          end
        end
      end
      rescue => e
        @logger.error("Error processing #{dest_file}: #{e.class.name} '#{e.message}' #{e.backtrace[0]}")
        raise
    end

    private

    def ensure_dir(dirname)
      return if Dir.exist?(dirname)
      @logger.debug("Creating new directory #{dirname}")
      Dir.mkdir(dirname)
      File.chown(nil, @group, dirname)
      File.chmod(02775, dirname)
    end

    def import_file(source: nil, dest: nil, mode: 0664)
      @logger.info("Copying #{source} to #{dest}")
      FileUtils.cp(source, dest)
      File.chmod(mode, dest)
      @logger.debug("Chmod done on  #{dest}.")
      num_chowned = File.chown(nil, @group, dest)
      @logger.debug("Chowned #{num_chowned} files.")
      if FileUtils.compare_file(source, dest)
        File.delete(source)
      else
        fail "#{source} and #{dest} not identical."
      end
    end
  end
end

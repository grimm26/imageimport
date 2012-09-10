#!/usr/bin/python3

import re
import os
from subprocess import check_output
import subprocess
import pyinotify
import argparse
import logging
import magic

# Parse command line args
parser = argparse.ArgumentParser(description='process image import directory')
parser.add_argument("--loglevel", "--log", default="INFO",
        help="Set level of log messages to receive.")
parser.add_argument("--watch", default='/raid/media/pictures/dumpdir/', 
        help="The directorty to watch for incoming images.")
parser.add_argument("--destination", default='/raid/media/pictures/', 
        help="The top of the directorty in which to place imported images.")
args = parser.parse_args()

# get the numeric for the string loglevel provided and set the logging config.
numeric_level = getattr(logging, args.loglevel.upper(), None)
if not isinstance(numeric_level, int):
    raise ValueError('Invalid log level: %s' % loglevel)
logging.basicConfig(format='%(asctime)s %(filename)s: %(levelname)s %(message)s', level=numeric_level )

# Set directories based on args
DUMP_DIR = args.watch
DEST_DIR = args.destination

def import_image(filename):
    """Move the image file from the DUMP_DIR to the DEST_DIR"""

    # We end up back here when we remove a duplicate so let's just bail out
    # right away if the file isn't here.
    if not os.path.exists(filename):
        return False

    ms = magic.open(magic.NONE)
    ms.load()
    tp = ms.file(filename)
    if not (re.search(r"^JPEG image data",tp)):
        return False

    try:
        jhead_out = str(check_output(["jhead", filename]),'utf8')
    except subprocess.CalledProcessError as err:
        logging.error('%s %s %s',err,err.returncode,err.output)
        return False

    m = re.search(r"^Date/Time\s+:\s+(?P<year>\d+):(?P<month>\d+):(?P<day>\d+)\s+(?P<hour>\d+):(?P<min>\d+):(?P<sec>\d+)",
            jhead_out,re.MULTILINE)
    ts = m.groupdict()
    if "year" not in ts:
        logging.info("No date info in image %s",filename)
        return False

    # Build the destination directory and full filename
    dest_dir = os.path.join( DEST_DIR,'_'.join([ ts['year'], ts['month'], ts['day'] ]) )
    dest_file = os.path.join( dest_dir,
        '_'.join([ ts['year'], ts['month'], ts['day'] ]) +'-'+ 
        '_'.join([ ts['hour'], ts['min'], ts['sec'] ]) + '.jpg' )
    # check if it is already there, otherwise put it there
    if os.path.exists(dest_file):
        logging.debug("Skipping duplicate %s", dest_file)
        try:
            os.remove(filename)
            logging.debug("Removed duplicate %s", filename)
        except OSError:
            logging.warning("Could not remove %s",filename)
    else:
        try:
            if not os.path.isdir(dest_dir):
                os.mkdir(dest_dir,0o775)
            os.rename(filename,dest_file)
            logging.info("%s --> %s",filename,dest_file)
            return True
        except OSError as err:
            logging.error("File error: %s",err.strerror)
#

# The watch manager stores the watches and provides operations on watches
wm = pyinotify.WatchManager()

mask = pyinotify.IN_CLOSE_WRITE | pyinotify.IN_MOVED_TO  # watched events
# Set up a handler
class EventHandler(pyinotify.ProcessEvent):
    def process_IN_CLOSE_WRITE(self, event):
        logging.debug("File written: %s", event.pathname)
        if re.search(r"^(?!\.).+\.jpg$", event.name, re.I):
            import_image(event.pathname)
    def process_IN_MOVED_TO(self, event):
        logging.debug("File moved to: %s", event.pathname)
        if re.search(r"^(?!\.).+\.jpg$", event.name, re.I):
            import_image(event.pathname)

handler = EventHandler()
notifier = pyinotify.Notifier(wm, handler)

# Internally, 'handler' is a callable object which on new events will be called like this: 
# handler(new_event)
try:
    wdd = wm.add_watch(DUMP_DIR,
                             mask, auto_add=True, quiet=False, rec=True)
except pyinotify.WatchManagerError as err:
    logging.error('%s %s',err, err.wmd)

logging.info("Watching directory %s for incoming images.",DUMP_DIR)

notifier.loop()

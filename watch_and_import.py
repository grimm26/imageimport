#!/usr/bin/python3

import re
import os
from subprocess import check_output
import pyinotify

DUMP_DIR = '/raid/media/pictures/dumpdir/'
DEST_DIR = '/raid/media/pictures/'

def import_image(filename):
    try:
        jhead_out = str(check_output(["jhead", filename]),'utf8')
    except subprocess.CalledProcessError as err:
        print("ERROR:",err,err.returncode,err.output)

    m = re.search(r"^Date/Time\s+:\s+(?P<year>\d+):(?P<month>\d+):(?P<day>\d+)\s+(?P<hour>\d+):(?P<min>\d+):(?P<sec>\d+)",
            jhead_out,re.MULTILINE)
    ts = m.groupdict()
    if "year" not in ts:
        print("No date info in image",filename)
        return False

    # Build the destination directory and full filename
    dest_dir = os.path.join( DEST_DIR,'_'.join([ ts['year'], ts['month'], ts['day'] ]) )
    dest_file = os.path.join( dest_dir,
        '_'.join([ ts['year'], ts['month'], ts['day'] ]) +'-'+ 
        '_'.join([ ts['hour'], ts['min'], ts['sec'] ]) + '.jpg' )
    # check if it is already there, otherwise put it there
    if os.path.exists(dest_file):
        print("Skipping duplicate", dest_file)
        try:
            os.remove(filename)
        except OSError:
            print("Could not remove",filename)
    else:
        try:
            if not os.path.isdir(dest_dir):
                os.mkdir(dest_dir,0o775)
            os.rename(filename,dest_file)
            print(filename,"-->",dest_file)
            return True
        except OSError as err:
            print("File error:",err.strerror)
#

# The watch manager stores the watches and provides operations on watches
wm = pyinotify.WatchManager()

mask = pyinotify.IN_CLOSE_WRITE | pyinotify.IN_MOVED_TO  # watched events
# Set up a handler
class EventHandler(pyinotify.ProcessEvent):
    def process_IN_CLOSE_WRITE(self, event):
        print("Written:", event.pathname)
        if re.search(r"\.jpg$", event.name, re.I):
            import_image(event.pathname)
    def process_IN_MOVED_TO(self, event):
        print("Moved to:", event.pathname)
        if re.search(r"\.jpg$", event.name, re.I):
            import_image(event.pathname)

handler = EventHandler()
notifier = pyinotify.Notifier(wm, handler)

# Internally, 'handler' is a callable object which on new events will be called like this: 
# handler(new_event)
try:
    wdd = wm.add_watch(DUMP_DIR,
                             mask, auto_add=True, quiet=False, rec=True)
except pyinotify.WatchManagerError as err:
    print("Error:",err, err.wmd)

notifier.loop()

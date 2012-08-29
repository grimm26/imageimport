#!/usr/bin/python3

import pyinotify

# The watch manager stores the watches and provides operations on watches
wm = pyinotify.WatchManager()

mask = pyinotify.IN_CLOSE_WRITE | pyinotify.IN_CREATE | pyinotify.IN_MOVED_TO  # watched events
# Set up a handler
class EventHandler(pyinotify.ProcessEvent):
    def process_IN_CLOSE_WRITE(self, event):
        print("Written:", event.pathname)
    def process_IN_CREATE(self, event):
        print("Created:", event.pathname)
    def process_IN_MOVED_TO(self, event):
        print("Moved to:", event.pathname)

handler = EventHandler()
notifier = pyinotify.Notifier(wm, handler)

# Internally, 'handler' is a callable object which on new events will be called like this: 
# handler(new_event)
try:
    wdd = wm.add_watch(['/raid/media/pictures/dumpdir/','/tmp/foohjhj'], 
                             mask, auto_add=True, quiet=False, rec=True)
except pyinotify.WatchManagerError as err:
    print(err, err.wmd)

notifier.loop()

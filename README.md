imageimport
===========

Watch a directory for images to be dumped into to rename and organize them.


The Itch
========
I have used a script to take images off of my camera memory cards and organize them by putting
them into directories named by the date they were taken and renaming the image to the timestamp
it was taken.  For example: IMG1213.JPG becomes 2012_07_28/2012_07_28-12_07_30.jpg
The problem with this became that to upload my pictures I needed to sit in front of a Linux
box with an SD card reader.

The Scratch
===========
I decided to put the work onto the server.  Using inotify, I can watch a directory for when
pictures get added to it and then do my thing.  It no longer matters how the pictures get
taken off of the camera as long as they get put into the "dump" directory for new pictures.

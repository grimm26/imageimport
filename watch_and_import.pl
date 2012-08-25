#!/usr/bin/perl
# This script will monitor a directory that images from your camera or wherever will be downloaded to.
# As new images come in, the script will rename them based on EXIF timestamp data.

# External requirements: jhead

use feature 'say';
use Linux::Inotify2;
use File::Find;
use Getopt::Long;
use Sys::Syslog qw(:standard :macros);

use warnings;
use strict;

our $debug = 0;
our $syslog = 0;
GetOptions ("debug" => \$debug, "syslog" => \$syslog );
if ($syslog) {
    openlog($0,'pid',LOG_DAEMON);
}

# Where images will be dumped.
use constant DUMP_DIR => '/raid/media/pictures/dumpdir/';
use constant DEST_DIR => '/raid/media/pictures/';

# create a new inotify object
my $inotify = new Linux::Inotify2
    or (syslog(LOG_ERR,'unable to create new inotify object: %m') and die "unable to create new inotify object: $!\n");
 
find({ wanted => \&watch_dirs, no_chdir => 1 }, DUMP_DIR);

# keep polling :)
1 while $inotify->poll;

sub watchit {
    my $e = shift;
    my $fullname = $e->fullname;
    my $name = $e->name;
    # if a dir was created, start watching it
    if ( ($e->IN_CREATE or $e->IN_MOVED_TO) and -d $fullname) {
        $inotify->watch ($fullname, IN_MOVED_TO|IN_CLOSE_WRITE|IN_CREATE|IN_DELETE_SELF|IN_ONLYDIR, \&watchit);
        &dolog(LOG_DEBUG, "Now watching $fullname");
    } elsif ($e->IN_DELETE_SELF) {
        &dolog(LOG_DEBUG, "No longer watching $fullname");
        $e->w->cancel;
    } else {
        my @list = ();
        &dolog(LOG_DEBUG,"$fullname ($name) was written");
        if ( $name =~ /\.jpg$/i ) {
            sleep 1;
            open JHEAD, "jhead $fullname|" or 
                (&dolog(LOG_ERR, "Could not jhead $fullname. Skipping.") and return);
            while (<JHEAD>) {
                if (m!^Date/Time\s+:\s+(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)!) {
                    my $year  = $1;
                    my $month = $2;
                    my $day   = $3;
                    my $hour  = $4;
                    my $min   = $5;
                    my $sec   = $6;
                    my $dest  = DEST_DIR. "${year}_${month}_${day}";
                    if (-r "$dest/${year}_${month}_${day}-${hour}_${min}_${sec}.jpg") {
                        &dolog(LOG_NOTICE, "Skipping duplicate $dest/${year}_${month}_${day}-${hour}_${min}_${sec}.jpg"); 
                        unlink $fullname;
                        last;
                    }
                    if (-r "$dest/${year}_${month}_${day}-${hour}-${min}_${sec}.jpg") {

                        &dolog(LOG_NOTICE, "Skipping duplicate $dest/${year}_${month}_${day}-${hour}-${min}_${sec}.jpg");
                        unlink $fullname;
                        last;
                    }
                    push @list, $dest;
                    system "mkdir $dest" unless -d "$dest";
                    rename($fullname, "$dest/$name") or (&dolog(LOG_ERR, "Could not move $name: $!"));
                    my $rename = `jhead  -n%Y_%m_%d-%H_%M_%S $dest/$name`;
                    &dolog(LOG_NOTICE, $rename);
                    last;
                }
            }
            close JHEAD;
            foreach (@list) {
                system "chmod -R 775 $_";
            }
        }
    }
}

sub dolog {
    my $priority = shift;
    my $mesg = shift;
    if ($syslog) {
        syslog($priority,$mesg);
    }
    if ($debug) {
        say $mesg;
    }
}

sub watch_dirs {
    # watch for when a write filehandle is closed.
    $inotify->watch ($File::Find::dir, IN_MOVED_TO|IN_CLOSE_WRITE|IN_CREATE|IN_DELETE_SELF|IN_ONLYDIR, \&watchit);
    &dolog(LOG_DEBUG, "Now watching $File::Find::dir");
}

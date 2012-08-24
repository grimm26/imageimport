#!/usr/bin/perl
# This script will monitor a directory that images from your camera or wherever will be downloaded to.
# As new images come in, the script will rename them based on EXIF timestamp data.

# External requirements: jhead

use Linux::Inotify2;
use Getopt::Long;

use warnings;
use strict;

my $debug = 0;
GetOptions ("debug" => \$debug );

# Where images will be dumped.
use constant DUMP_DIR => '/raid/media/pictures/dumpdir/';
use constant DEST_DIR => '/raid/media/pictures/';

# create a new object
my $inotify = new Linux::Inotify2
    or die "unable to create new inotify object: $!";
 
# watch for when a write filehandle is closed.
$inotify->watch (DUMP_DIR, IN_MOVED_TO|IN_CLOSE_WRITE|IN_CREATE|IN_DELETE_SELF|IN_ONLYDIR, \&watchit);

sub watchit {
    my $e = shift;
    my $fullname = $e->fullname;
    my $name = $e->name;
    # if a dir was created, start watching it
    if ($e->IN_CREATE and -d $fullname) {
        $inotify->watch (DUMP_DIR, IN_MOVED_TO|IN_CLOSE_WRITE|IN_CREATE|IN_DELETE_SELF|IN_ONLYDIR, \&watchit);
        print "Now watching $fullname\n" if $debug;
    } elsif ($e->IN_DELETE_SELF) {
        print "No longer watching $fullname\n" if $debug;
        $e->w->cancel;
    } else {
        my @list = ();
        print "$fullname ($name) was written.\n" if $debug;
        if ( $name =~ /\.jpg$/i ) {
            sleep 1;
            open JHEAD, "jhead $fullname|" or die "Could not jhead $fullname\n";
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
                        print "Skipping duplicate $dest/${year}_${month}_${day}-${hour}_${min}_${sec}.jpg\n" 
                            if $debug;
                        unlink $fullname;
                        last;
                    }
                    if (-r "$dest/${year}_${month}_${day}-${hour}-${min}_${sec}.jpg") {

                        print "Skipping duplicate $dest/${year}_${month}_${day}-${hour}-${min}_${sec}.jpg\n"
                            if $debug;
                        unlink $fullname;
                        last;
                    }
                    push @list, $dest;
                    system "mkdir $dest" unless -d "$dest";
                    rename($fullname, "$dest/$name") or warn "Could not move $name: $!\n";
                    system "jhead  -n%Y_%m_%d-%H_%M_%S $dest/$name";
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

# keep polling :)
1 while $inotify->poll;


#!/usr/bin/perl -w
# 
# ooPhotoParse.pl, DESCRIPTION
# 
# Copyright (C) 2007 Jonathan J. Miner
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# $Id:$
# Jonathan J. Miner <miner@doit.wisc.edu>

use vars qw/$VERSION $FILE/;
($VERSION) = q$Revision: 1.1 $ =~ /([\d.]+)/;
($FILE) = q$RCSfile: ooPhotoParse.pl,v $ =~ /^[^:]+: ([^\$]+),v $/;

use strict;

use strict;
use iPhotoLibrary;
use File::Copy;
use File::Basename;
use Image::ExifTool;

use Data::Dumper;

my @library_options = (
    'AlbumData.xml',
    glob( '~/Pictures/iPhoto\ Library/AlbumData.xml' ),
);

my $lib_file = shift;

if (!defined($lib_file)) {
    foreach ( @library_options ) {
        if ( -r $_ ) {
            $lib_file = $_;
            last;
        }
    }
}

unless( defined($lib_file) ) {
    die( 'No suitable library found or specified.' );
}

print STDERR "Using Library file: $lib_file\n";

my $library = new iPhotoLibrary(
    file => $lib_file,
    debug => 1,
);

my $file_loc = (
    OriginalPath => 'Orig',
    ImagePath => 'Mod',
);

open VERBOSELOG, ">>verbose_exif.log";

foreach my $image ( $library->images ) {
    print "Image: ", $image->{ID}, "\n";
    foreach my $key ( keys %{ $image } ) {
        print "   $key: ";
        if ( ref( $image->{$key} ) eq 'ARRAY' ) {
            print join( ', ', @{$image->{$key}});
        } else {
            print $image->{$key};
        }
        print "\n";
    }

}

sub album_path {
    my $library = shift;
    my $album_num = shift;

    my $album_parent = $library->get_album( $album_num )->{Parent};

    if ( defined($album_parent) ) {
        return album_path( $album_parent ), $album_num;
    }
    return $album_num;
}

sub img_copy {
    my $orig = shift;
    my $dest = shift;
    my $roll = shift;

    my $real_dest = join( '/', $dest, $roll );

    mkdir $real_dest if ( ! -d $real_dest );

    my $basename = basename( $orig );

    print STDERR "Copying $basename to $real_dest\n";

    copy( $orig, $real_dest ) or die( "Copy failed: $!" );

    return join( '/', $real_dest, $basename );
}

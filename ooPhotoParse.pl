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

foreach my $img_num ( 5554, 23397, 6474, 7652 ) {
    my $image = $library->get_image( $img_num );

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

    my @files = ();

    if ( defined($image->{OriginalPath}) ) {
        push @files, img_copy(  $image->{OriginalPath}, 'Orig', $image->{Roll} );
    }
    push @files, img_copy(  $image->{ImagePath}, 'Images', $image->{Roll} );

    print "Files: ", join( ',', @files ), "\n";

    foreach my $file ( @files ) {
        my $exifTool = new Image::ExifTool;

        $exifTool->Options( 'Composite' => 0 );
        $exifTool->Options( 'TextOut' => \*VERBOSELOG );
        $exifTool->Options( 'Verbose' => 3 );

        print "Processing $file...\n";

        unless( $exifTool->ExtractInfo( $file ) ) {
            print STDERR "  Error reading $file.. WTF?\n";
            print STDERR "  Error Value: ", $exifTool->GetValue('Error'), "\n";
        }

        if ( $exifTool->GetValue( 'Warning' ) ) {
            print "  Warning: ", $exifTool->GetValue( 'Warning' ), "\n";
        }

        print "   Found Tags ($file):\n", map( "    $_\n", $exifTool->GetFoundTags ), "\n\n";

        my $comment = $exifTool->GetValue( 'Comment' );
        # $comment =~ s/\r//g;
        print "Comment: $comment\n" if ( $comment );

        if ( $comment =~ /KONICA MINOLTA DIGITAL CAMERA/ ) {
            print "  Comment is camera!\n";
            # delete it.
            $exifTool->SetNewValue( 'Comment' );
        }

        my $descr = $exifTool->GetValue( 'ImageDescription' );

        if ( $descr  =~ /KONICA MINOLTA DIGITAL CAMERA/ ) {
            print "  Description is camera!\n";
            # delete it.
            $exifTool->SetNewValue( 'ImageDescription' );
        }

        $comment = $image->{Comment};
        $exifTool->SetNewValue( 'Comment', $comment ) if ( $comment );
        my @keywords = map sprintf( 'iPhotoKeyword-%s', $library->get_keyword( $_ )), @{ $image->{Keywords} } if ( $image->{Keywords} );
        
        my @albums = ();
        foreach my $a ( ref( $image->{Album} ) ? @{ $image->{Album} } : $image->{Album} ) {
            push @albums, sprintf( 'iPhotoAlbum-%s', join( '-', map( $library->get_album( $_ )->{Name}, $library->get_album( $a )->album_path ) ) );
        }

        print "Keywords: ", join( ',', @keywords ), "\n";
        print "Albums: ", join( ',', @albums ), "\n";
        $exifTool->SetNewValue( 'Keywords', [ @keywords, @albums ] ) if ( scalar @keywords );

        my $caption = $image->{Caption};
        print "Caption: $caption\n";
        if (
            $caption eq basename( $file )
            || $caption eq basename( $file, '.jpg' )
            || $caption eq basename( $file, '.jpeg' )
            || $caption eq basename( $file, '.JPG' )
            || $caption eq basename( $file, '.JPEG' )
        ) {
            print "Caption is Base name.\n";
            $caption = undef;
        }
        $exifTool->SetNewValue( 'Title', $caption ) if ( defined($caption) );
        $exifTool->SetNewValue( 'ObjectName', $caption ) if ( defined($caption) );

        print "Writing $file..\n";
        my $retval = $exifTool->WriteInfo( $file );

        print "No changes made on write.." if ($retval == 2);

        unless ($retval) {
            print "Error: ", $exifTool->GetValue( 'Error' );
            print "Warning: ", $exifTool->GetValue( 'Warning' );
        }
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

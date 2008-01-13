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

foreach my $img_num (
    5554,
    23397,
    6474,
    7652,
    21836,
    21881,
    23792,
) {
    my $image = $library->get_image( $img_num );

    print STDERR "Image: ", $image->{ID}, "\n";
    foreach my $key ( keys %{ $image } ) {
        print STDERR "   $key: ";
        if ( ref( $image->{$key} ) eq 'ARRAY' ) {
            print STDERR join( ', ', @{$image->{$key}});
        } else {
            print STDERR $image->{$key};
        }
        print STDERR "\n";
    }

    my @files = ();

    if ( defined($image->{OriginalPath}) && ! defined( $image->{RAW} )) {
        push @files, img_copy(  $image->{OriginalPath}, 'Orig', $image->{Roll} );
    }
    # If RAW, copy it to the image directory and skip the JPG, it's only a cache
    # of the RAW.
    push @files, img_copy(
        defined( $image->{RAW} ) ? $image->{OriginalPath} : $image->{ImagePath},
        'Images',
        $image->{Roll}
    );

    print STDERR "Files: ", join( ',', @files ), "\n";

    foreach my $file ( @files ) {
        my $exifTool = new Image::ExifTool;

        $exifTool->Options( 'Composite' => 0 );
        $exifTool->Options( 'TextOut' => \*VERBOSELOG );
        $exifTool->Options( 'Verbose' => 3 );

        print STDERR "Processing $file...\n";

        unless( $exifTool->ExtractInfo( $file ) ) {
            print STDERR "  Error reading $file.. WTF?\n";
            print STDERR "  Error Value: ", $exifTool->GetValue('Error'), "\n";
        }

        if ( $exifTool->GetValue( 'Warning' ) ) {
            print STDERR "  Warning: ", $exifTool->GetValue( 'Warning' ), "\n";
        }

        print STDERR "   Found Tags ($file):\n", map( "    $_\n", $exifTool->GetFoundTags ), "\n\n";

        my $comment = $exifTool->GetValue( 'Comment' );
        # $comment =~ s/\r//g;
        print STDERR "Comment: $comment\n" if ( $comment );

        if ( $comment =~ /KONICA MINOLTA DIGITAL CAMERA/ ) {
            print STDERR "  Comment is camera!\n";
            # delete it.
            $exifTool->SetNewValue( 'Comment' );
        }

        my $descr = $exifTool->GetValue( 'ImageDescription' );

        if ( $descr  =~ /KONICA MINOLTA DIGITAL CAMERA/ ) {
            print STDERR "  Description is camera!\n";
            # delete it.
            $exifTool->SetNewValue( 'ImageDescription' );
        }

        my $retval = undef;
        my $errstr = undef;

        $comment = $image->{Comment};
        if ( defined($comment) ) {
            foreach my $attr ( 'Description', 'Caption-Abstract' ) {
                ($retval, $errstr) = $exifTool->SetNewValue( $attr, $comment );
                if ( $retval == 0 || defined($errstr) ) {
                    print STDERR "Error on $attr ($retval): $errstr\n";
                }
            }
        }

        my @keywords = ();
        
        @keywords = map sprintf( 'iPhotoKeyword-%s', $library->get_keyword( $_ )), @{ $image->{Keywords} } if ( $image->{Keywords} );

        print STDERR "Keywords 1: ", join( ', ', @keywords ), "\n";
        
        my @albums = ();
        foreach my $a ( ref( $image->{Album} ) ? @{ $image->{Album} } : $image->{Album} ) {
            push @albums, sprintf( 'iPhotoAlbum-%s', join( '-', map( $library->get_album( $_ )->{Name}, $library->get_album( $a )->album_path ) ) ) if (defined($a));
        }

        push @albums, sprintf( 'iPhotoRoll-%d-%s', $image->{Roll}, $library->{rolls}->{ $image->{Roll} }->{Name} );

        if ( defined($image->{OriginalPath}) ) {
            print STDERR "Photo has Original Path.\n";
            if ( $file =~ /Orig/ ) {
                push @keywords, 'iPhotoOriginalImage';
            } else {
                push @keywords, 'iPhotoModifiedImage';
            }
            if ( $image->{RotatedOnly} ) {
                push @keywords, 'iPhotoRotatedOnly';
            }
        }

        print STDERR "Keywords: ", join( ',', @keywords ), "\n";
        print STDERR "Albums: ", join( ',', @albums ), "\n";
        if ( scalar @keywords || scalar @albums ) {
            print STDERR "Setting Keywords to: ", join( ',', @keywords, @albums ), "\n";
            ($retval, $errstr) = $exifTool->SetNewValue( 'Keywords', [ @keywords, @albums ] );
            print STDERR "Set $retval values..\n";
            if ( defined($errstr) ) {
                print STDERR "Error on Keywords ($retval): $errstr\n";
            }
        }

        my $caption = $image->{Caption};
        print STDERR "Caption: $caption\n";
        if (
            $caption eq basename( $file )
            || $caption eq basename( $file, '.jpg' )
            || $caption eq basename( $file, '.jpeg' )
            || $caption eq basename( $file, '.JPG' )
            || $caption eq basename( $file, '.JPEG' )
            || $caption eq basename( $file, '.nef' )
            || $caption eq basename( $file, '.NEF' )
        ) {
            print STDERR "Caption is Base name.\n";
            $caption = undef;
        }

        ($retval, $errstr) = $exifTool->SetNewValue( 'Title', $caption ) if ( defined($caption) );
        if ( $retval == 0 || defined($errstr) ) {
            print STDERR "Error on Title ($retval): $errstr\n";
        }
        ($retval, $errstr) = $exifTool->SetNewValue( 'ObjectName', $caption ) if ( defined($caption) );
        if ( $retval == 0 || defined($errstr) ) {
            print STDERR "Error on ObjectName ($retval): $errstr\n";
        }

        my $rating = $image->{Rating};

        print STDERR "Rating: $rating\n";

        ($retval, $errstr) = $exifTool->SetNewValue( 'Rating', $image->{Rating} ) if ( $image->{Rating} );
        if ( $retval == 0 || defined($errstr) ) {
            print STDERR "Error on Rating ($retval): $errstr\n";
        }

        print STDERR "Writing $file..\n";
        my $retval = $exifTool->WriteInfo( $file );

        print STDERR "No changes made on write..\n" if ($retval == 2);

        unless ($retval) {
            print STDERR "Error: ", $exifTool->GetValue( 'Error' );
            print STDERR "Warning: ", $exifTool->GetValue( 'Warning' );
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

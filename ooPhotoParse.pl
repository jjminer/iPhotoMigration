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

my $starttime = time;
print STDERR "Start: ", scalar localtime($starttime), "\n";
print "Start: ", scalar localtime($starttime), "\n";

print STDERR "Using Library file: $lib_file\n";
print "Using Library file: $lib_file\n";

my $library = new iPhotoLibrary(
    file => $lib_file,
    debug => 1,
);

my $starttime2 = time;
print STDERR "Post Library Start: ", scalar localtime($starttime2), "\n";
print "Post Library Start: ", scalar localtime($starttime2), "\n";

open VERBOSELOG, ">>verbose_exif.log";

my $num_processed = 0;
my $num_toprocess = undef;

if (0) {
    $num_toprocess = scalar keys %{$library->{images}};
    print STDERR "Number to process: $num_toprocess\n";

    foreach my $img ( $library->images ) {
        process_item( $img );
    }
}
else {
    my @image_nums = (
        5554,
        23397,
        6474,
        7652,
        21836,
        21881,
        23792,
        16043,
        778,
        21640,
    );

    $num_toprocess = scalar @image_nums;
    print STDERR "Number to process: $num_toprocess\n";

    foreach my $img_num ( @image_nums ) {
        process_item( $library->get_image( $img_num ) );
    }
}

my $finishtime = time;

print STDERR "\n\nFinished: ", scalar localtime($finishtime), "\n";
print "Finished: ", scalar localtime($finishtime), "\n";

print STDERR "Elapsed time: ", $finishtime - $starttime, "\n";
print "Elapsed time: ", $finishtime - $starttime, "\n";

print STDERR "Elapsed non-library load time: ", $finishtime - $starttime2, "\n";
print "Elapsed non-library load time: ", $finishtime - $starttime2, "\n";

sub process_item {
    my $item = shift;

    print STDERR "." if ( (++$num_processed % 100) == 0);
    print STDERR "$num_processed/$num_toprocess" if ( ($num_processed % 1000 ) == 0 );

    print "\nItem: ", $item->{ID}, " ($num_processed/$num_toprocess)\n";

    dump_iphoto_info( $item );

    if ( $item->{MediaType} eq 'Image' ) {
        process_image( $item );
    }
    elsif ($item->{MediaType} eq 'Movie' ) {
        process_movie( $item );
    }

}

sub process_movie {
    my $movie = shift;

    my @files = ();
    if ( defined($movie->{OriginalPath}) ) {
        push @files, img_copy(  $movie->{OriginalPath}, 'Movies', 'Orig', $movie->{Roll} );
    }
    push @files, img_copy(
        $movie->{ImagePath},
        'Movies',
        'Curr',
        $movie->{Roll}
    );

    foreach my $file ( @files ) {
        my @keywords = ();

        @keywords = map sprintf( '%s', $library->get_keyword( $_ )), @{ $movie->{Keywords} } if ( $movie->{Keywords} );

        # print "Keywords 1: ", join( ', ', @keywords ), "\n";
        
        my @albums = ();
        foreach my $a ( ref( $movie->{Album} ) ? @{ $movie->{Album} } : $movie->{Album} ) {
            push @albums, sprintf( '%s', join( ' / ', map( $library->get_album( $_ )->{Name}, $library->get_album( $a )->album_path ) ) ) if (defined($a));
        }

        my $roll = sprintf( '%d-%s', $movie->{Roll}, $library->{rolls}->{ $movie->{Roll} }->{Name} );
        open TEXT, ">$file.txt";

        print TEXT "Documentation for $file\n\n";

        foreach my $key ( 'Caption', 'Comment' ) {
            my $val = $movie->{$key};
            $val =~ s/^\s*$//;
            $val =~ s/^\s*//;
            $val =~ s/\s*$//;
            print TEXT "$key: $val\n\n" if (
                defined($movie->{$key})
                && $val !~ /^\s*$/
            );
        }

        print TEXT "Roll: $roll\n\n";
        if ( scalar @keywords ) {
            print TEXT "Keywords:\n";
            print TEXT map "  $_\n", @keywords;
            print TEXT "\n";
        }

        if ( scalar @albums ) {
            print TEXT "Albums:\n";
            print TEXT map "  $_\n", @albums;
            print TEXT "\n";
        }

        print TEXT "Rating: ", $movie->{Rating}, "\n";

        close TEXT;

    }
}

sub process_image {

    my $image = shift;

    my @files = ();

    my $oddcase = 0;

    if ( defined($image->{OriginalPath}) && ! defined( $image->{RAW} )) {
        if ( ! -e $image->{OriginalPath} && -e $image->{ImagePath} ) {
            print STDERR "\n Weird.  Original missing, but Modified exists for ", $image->{ID}, "\n";
            print " Weird.  Original missing, but Modified exists for ", $image->{ID}, "\n";
            $oddcase = 1;
        } else {
            push @files, img_copy(  $image->{OriginalPath}, 'Images', 'Orig', $image->{Roll} );
        }
    }
    # If RAW, copy it to the image directory and skip the JPG, it's only a cache
    # of the RAW.
    push @files, img_copy(
        defined( $image->{RAW} ) ? $image->{OriginalPath} : $image->{ImagePath},
        'Images',
        'Curr',
        $image->{Roll}
    );

    print "Files: ", join( ',', @files ), "\n";

    foreach my $file ( @files ) {
        my $exifTool = new Image::ExifTool;

        $exifTool->Options( 'Composite' => 0 );
 
        # Dammit.  None of these seem to work with the NikonMaker error.  Stupid
        # stupid.
        # $exifTool->Options( 'IgnoreMinorErrors' => 1 );
        # $exifTool->Options( 'FixBase' => 1 );
        # $exifTool->Options( 'IgnoreMinorErrors' => 1 );
        # $exifTool->Options( 'MakerNotes' => 2 );
        #
        # $exifTool->Options( 'TextOut' => \*VERBOSELOG );
        # $exifTool->Options( 'Verbose' => 3 );

        my $basename = basename( $file );
        print "Processing $basename ($file)...\n";

        unless( $exifTool->ExtractInfo( $file ) ) {
            print STDERR "\n  Error reading $file.. WTF?\n";
            print STDERR "\n  Error Value: ", $exifTool->GetValue('Error'), "\n";
            print "  Error reading $file.. WTF?\n";
            print "  Error Value: ", $exifTool->GetValue('Error'), "\n";
        }

        my $nowrite_error = 0;

        my $fh = undef;
        my $move_to_dir = undef;

        if ( scalar $exifTool->GetValue( 'Warning' ) ) {
            print "  Warning on Load: ", $exifTool->GetValue( 'Warning' ), "\n";
            if ( $exifTool->GetValue( 'Warning' ) eq 'Bad ExifIFD directory pointer for MakerNoteNikon3' ) {

                # XXX - Need to figure out what we do here... can't write the
                # file.  That's not good.
                print " Writing info to text file...  Can't write.\n";
                $nowrite_error = 1;

                $move_to_dir = mkdir_path(
                    'Bad_Images',
                    $file =~ m!/Orig/! ? 'Orig' : 'Curr',
                    $image->{Roll},
                );

                $fh = new IO::File( "> $move_to_dir/$basename-info.txt" );
            }
        }

        if ( scalar $exifTool->GetValue( 'Error' ) ) {
            print STDERR "  Error on Load: ", $exifTool->GetValue( 'Error' ), "\n";
            print "  Error on Load: ", $exifTool->GetValue( 'Error' ), "\n";
        }

        # print "   Found Tags ($file):\n", map( "    $_\n", $exifTool->GetFoundTags ), "\n\n";

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

        my $retval = undef;
        my $errstr = undef;

        $comment = $image->{Comment};
        if ( defined($comment) ) {
            if ( $comment !~ /^\s*$/ ) {
                foreach my $attr ( 'Description', 'Caption-Abstract' ) {
                    ($retval, $errstr) = $exifTool->SetNewValue( $attr, $comment );
                    if ( $retval == 0 || defined($errstr) ) {
                        print STDERR "\nError on $attr ($retval): $errstr\n";
                        print "Error on $attr ($retval): $errstr\n";
                    }
                }

                if ( $nowrite_error && defined($fh) ) {
                    $fh->print( "Comment:\n  $comment\n\n" );
                }

            }
        }

        my @keywords = ();

        @keywords = map sprintf( 'iPhotoKeyword-%s', $library->get_keyword( $_ )), @{ $image->{Keywords} } if ( $image->{Keywords} );

        # print "Keywords 1: ", join( ', ', @keywords ), "\n";
        
        my @albums = ();
        foreach my $a ( ref( $image->{Album} ) ? @{ $image->{Album} } : $image->{Album} ) {
            push @albums, sprintf( 'iPhotoAlbum-%s', join( '-', map( $library->get_album( $_ )->{Name}, $library->get_album( $a )->album_path ) ) ) if (defined($a));
        }

        push @albums, sprintf( 'iPhotoRoll-%d-%s', $image->{Roll}, $library->{rolls}->{ $image->{Roll} }->{Name} );

        if ( defined($image->{OriginalPath}) ) {
            # print "Photo has Original Path.\n";
            if ( $file =~ /Orig/ ) {
                push @keywords, 'iPhotoOriginalImage';
            } else {
                push @keywords, 'iPhotoModifiedImage';
            }
            if ( $image->{RotatedOnly} ) {
                push @keywords, 'iPhotoRotatedOnly';
            }
        }

        push @keywords, 'iPhotoMissingOriginal' if ( $oddcase );

        if ( scalar @files == 2 ) {
            push @keywords, sprintf( 'iPhotoImage-%d', $image->{ID} );
        }

        # print "Keywords: ", join( ',', @keywords ), "\n";
        # print "Albums: ", join( ',', @albums ), "\n";
        if ( scalar @keywords || scalar @albums ) {
            print "Setting Keywords to: ", join( ',', @keywords, @albums ), "\n";
            ($retval, $errstr) = $exifTool->SetNewValue( 'Keywords', [ @keywords, @albums ] );
            print "Set $retval values..\n";
            if ( defined($errstr) ) {
                print STDERR "\nError on Keywords ($retval): $errstr\n";
                print "Error on Keywords ($retval): $errstr\n";
            }
            if ( $nowrite_error && defined($fh) ) {
                $fh->print( "Albums:\n", map( "  $_\n", @albums ), "\n" ) if ( scalar @albums );
                $fh->print( "Keywords:\n", map( "  $_\n", @keywords ), "\n" ) if ( scalar @keywords );
            }
        }

        my $caption = $image->{Caption};
        print "Caption: $caption\n";
        if (
            $caption eq basename( $file )
            || $caption eq basename( $file, '.jpg' )
            || $caption eq basename( $file, '.jpeg' )
            || $caption eq basename( $file, '.JPG' )
            || $caption eq basename( $file, '.JPEG' )
            || $caption eq basename( $file, '.nef' )
            || $caption eq basename( $file, '.NEF' )
        ) {
            print "Caption is Base name.\n";
            $caption = undef;
        }

        ($retval, $errstr) = $exifTool->SetNewValue( 'Title', $caption ) if ( defined($caption) );
        if ( $retval == 0 || defined($errstr) ) {
            print STDERR "\nError on Title ($retval): $errstr\n";
            print "Error on Title ($retval): $errstr\n";
        }
        ($retval, $errstr) = $exifTool->SetNewValue( 'ObjectName', $caption ) if ( defined($caption) );
        if ( $retval == 0 || defined($errstr) ) {
            print STDERR "\nError on ObjectName ($retval): $errstr\n";
            print "Error on ObjectName ($retval): $errstr\n";
        }

        if ( $nowrite_error && defined($fh) && defined($caption) ) {
            $fh->print( "Caption: $caption\n\n" );
        }

        my $rating = $image->{Rating};

        print "Rating: $rating\n";

        ($retval, $errstr) = $exifTool->SetNewValue( 'Rating', $image->{Rating} ) if ( $image->{Rating} );
        if ( $retval == 0 || defined($errstr) ) {
            print STDERR "\nError on Rating ($retval): $errstr\n";
            print "Error on Rating ($retval): $errstr\n";
        }

        if ( $nowrite_error && defined($fh) && $rating ) {
            $fh->print( "Rating: $rating\n\n" );
        }

        # now for the real fun... fixing the dates.

        print "Dates:\n";
        foreach my $attr (
            [ 'Date' => 'DateTimeOriginal' ],
            [ 'Date' => 'CreateDate' ],
            # [ 'Date' => 'DateTimeDigitized' ],
            [ 'ModDate' => 'ModifyDate' ],
        ) {
            my ( $iattr, $eattr ) = @$attr;

            print " Looking for $iattr/$eattr..\n";
            my $ival = $image->{$iattr};
            next unless ( defined( $ival ) );
            my $ival_str = epoch_to_exif( $ival );
            print "  Found $ival_str ($ival) in iPhoto $iattr...\n";
            my $eval = $exifTool->GetValue( $eattr );

            if ( $eval ) {
                print "  Found $eval in EXIF $eattr\n";
            } else {
                print "  No EXIF $eattr found.\n";
            }

            if ( ! defined( $eval ) ) {
                $exifTool->SetNewValue( $eattr, $ival_str );
            }

            if ( defined($eval) && $eval ne $ival_str ) {
                print "  **** EXIF and iPhoto mismatch!\n";
                $exifTool->SetNewValue( $eattr, $ival_str );
            }

        }

        if ( $nowrite_error && defined($fh) && $image->{Date} ) {
            $fh->print( "iPhoto Date: ", epoch_to_exif( $image->{Date} ), "\n" );
        }

        if ( $nowrite_error && defined($fh) && $image->{ModDate} ) {
            $fh->print( "iPhoto ModDate: ", epoch_to_exif( $image->{ModDate} ), "\n" );
        }


        print "Writing $file..\n";

        if ( ! $nowrite_error ) {
            my $retval = $exifTool->WriteInfo( $file );

            print "No changes made on write..\n" if ($retval == 2);

            unless ($retval) {
                print STDERR "\nError Writing: ", $exifTool->GetValue( 'Error' ), "\n";
                print "Error Writing: ", $exifTool->GetValue( 'Error' ), "\n";
                print "Warning Writing: ", $exifTool->GetValue( 'Warning' ), "\n";
            }
        }
        else {
            print "Cannot write $file, moved to ", img_move( $file, $move_to_dir ), "\n";

            $fh->close() if ( defined( $fh ) );
        }
        print "\n";

    }
    print "\n";

}

sub dump_iphoto_info {
    my $image = shift;

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

sub epoch_to_exif {
    my $edate = shift;

    return unless ( $edate );

    my @date = localtime( $edate );

    return sprintf(
        '%04d:%02d:%02d %02d:%02d:%02d',
        $date[5] + 1900, $date[4] + 1, $date[3],
        $date[2], $date[1], $date[0]
    );
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
    my $media = shift;
    my $dest = shift;
    my $roll = shift;

    my $basename = basename( $orig );

    my $real_dest = mkdir_path( $media, $dest, $roll );

    print "Copying $basename to $real_dest\n";

    unless ( copy( $orig, $real_dest ) ) {
        print STDERR "Copying $orig to $real_dest failed with: $!\n";
        print "Copying $orig to $real_dest failed with: $!\n";
        die( "Copy failed: $!" );
    }

    return join( '/', $real_dest, $basename );
}

sub img_move {
    my $source = shift;
    my $dest = shift;

    my $basename = basename( $source );

    print "Moving $basename from $source to $dest\n";

    unless ( move( $source, $dest ) ) {
        print STDERR "Moving $source to $dest failed with: $!\n";
        print "Moving $source to $dest failed with: $!\n";
        die( "Move failed: $!" );
    }

    return -d $dest ? join( '/', $dest, $basename ) : $dest;
}

sub mkdir_path {
    my @path = @_;

    return unless ( scalar @path );

    my $real_dest = undef;

    foreach my $dir ( @path ) {
        if (defined($real_dest)) {
            $real_dest .= "/$dir";
        }
        else {
            $real_dest = $dir;
        }
        if ( ! -d $real_dest ) {
            mkdir $real_dest;
            print "Making: $real_dest\n";
        }

    }

    return $real_dest;
}

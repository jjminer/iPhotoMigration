#!/usr/bin/perl -w
# 
# iPhotoParse.pl, DESCRIPTION
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
($FILE) = q$RCSfile: iPhotoParse.pl,v $ =~ /^[^:]+: ([^\$]+),v $/;

use strict;
use Mac::PropertyList::Foundation;

use Data::Dumper;
use Time::Local;

my $filename = shift || 'AlbumData.xml';

my $base_time = timegm( 0, 0, 0, 1, 1, 2001 );

my $max_list = 20;

print STDERR "File: $filename\n";

print STDERR "Loading...";

my $iphoto_library = new Mac::PropertyList::Foundation(
    file => $filename,
);

print STDERR "done.\n";

foreach my $key ( $iphoto_library->keys ) {
    my $val = $iphoto_library->get($key);
    # print "Key: ", perlValue( $key ), ' : ', $val ? ref($val) eq 'NSCFArray' || ref($val) eq 'NSCFDictionary' ? ref($val) : perlValue( $val ) : 'UHHH...', "\n";
    # print "$key: ", ref($val) ? join( ' ', ref($val), $val->count ) : $val, "\n";
    print "$key: $val\n";
}

## Dammit, doesn't work.  Need to implement as non-tied, I guess.

print "--- Keywords ---\n";

foreach my $key ( $iphoto_library->get('List of Keywords')->keys ) {
    print "$key: ", $iphoto_library->get('List of Keywords')->get($key), "\n";
}

print "--- Images ---\n";

my $count = 0;

my %images = ();

my %albums = ();

my $mil = $iphoto_library->get( 'Master Image List' );

my %mil_keys = ();
my %rating_values = ();
my %keyword_values = ();

while ( my $key = $mil->next_key ) {
    $count++;

    foreach my $pkey ( $mil->get( $key )->keys ) {
        $mil_keys{ $pkey }++;
        if ( "$pkey" eq 'Rating' ) {
            $rating_values{$mil->get( $key )->get( $pkey )}++;
        }
        if ( "$pkey" eq 'Keywords' ) {
            $keyword_values{join(',', $mil->get( $key )->get( $pkey )->values)}++;
        }
    }
}

print "Image Count: $count\n";
print "Image Keys:\n";
print map "  $_: $mil_keys{$_}\n", keys %mil_keys;
print "\n";
print "Rating Values:\n";
print map "  $_: $rating_values{$_}\n", keys %rating_values;
print "\n";
print "Keyword Values:\n";
print map "  $_: $keyword_values{$_}\n", keys %keyword_values;
print "\n";

my $lor = $iphoto_library->get( 'List of Rolls' );

print "--- Rolls (of ", $lor->count, ") ---\n";

$count = 0;

my %roll_keys = ();

while ( my $val = $lor->next_entry ) {
    $count++;

    foreach my $pkey ( $val->keys ) {
        $roll_keys{$pkey}++;
    }
}
print "Roll Count: $count\n";
print "Roll Keys:\n";
print map "  $_: $roll_keys{$_}\n", keys %roll_keys;
print "\n";

my $loa = $iphoto_library->get( 'List of Albums' );

print "--- Albums (of ", $loa->count, ") ---\n";

$count = 0;

my %album_keys = ();
my %album_types = ();

while ( my $val = $loa->next_entry ) {
    $count++;

    foreach my $pkey ( $val->keys ) {
        $album_keys{$pkey}++;

        if ( "$pkey" eq 'Album Type' ) {
            $album_types{$val->get($pkey)}++;
        }

        if (
            !defined( $val->get( 'Album Type' )) 
            # || $val->get( 'Album Type' ) eq 'Special Month'
            # || $val->get( 'Album Type' ) eq 'Special Roll'
            # || $val->get( 'Album Type' ) eq 'Shelf'
            # || $val->get( 'Master' )
            || $val->get( 'Album Type' ) eq 'Folder'
        ) {
            print "  $pkey: ", $val->get( $pkey ); 
            print " (", scalar localtime(
                $base_time + $val->get( $pkey )
            ), ")" if ( $pkey =~ /Date/ );
            print "\n";
            if ( ref($val->get( $pkey )) eq 'Mac::PropertyList::Foundation::array' ) {
                my $tmp_array = $val->get( $pkey );
                my $tcnt = 0;
                while ( my $ival = $tmp_array->next_entry ) {
                    print "    $ival\n";
                    if ( $tcnt++ > $max_list ) {
                        print "     (etc)\n";
                        last;
                    }
                }
            }
        }
    }

}

print "Album Count: $count\n";
print "Album Keys:\n";
print map "  $_: $album_keys{$_}\n", keys %album_keys;
print "\n";
print "Album Types\n";
print map "  $_: $album_types{$_}\n", keys %album_types;
print "\n";

__END__
sub perlValue {
    my $object = shift;
    return $object->description()->UTF8String();
}

__END__

my $iphoto_library = NSDictionary->dictionaryWithContentsOfFile_('AlbumData.xml');

print Dumper( $iphoto_library );

list_keys( $iphoto_library );

print "--- List of Albums ---\n";

list_array( $iphoto_library->objectForKey_( 'List of Albums' ), 'AlbumName' );

print "--- List of Keywords ---\n";

list_keys( $iphoto_library->objectForKey_( 'List of Keywords' ) );

sub list_keys {

    my $obj = shift;
    my @subkeys = @_;

    my $enum = $obj->keyEnumerator();

    while ( my $key = $enum->nextObject() ) {
        last unless ( $$key );
        next if ( scalar @subkeys && ! grep { $_ eq perlValue($key) } @subkeys );
        # print Dumper( $key );
        my $val = $obj->objectForKey_($key);
        print "Key: ", perlValue( $key ), ' : ', $val ? ref($val) eq 'NSCFArray' || ref($val) eq 'NSCFDictionary' ? ref($val) : perlValue( $val ) : 'UHHH...', "\n";
    }
}

sub list_array {

    my $obj = shift;
    my @subkeys = @_;

    my $enum = $obj->objectEnumerator();

    my $count = 0;

    while ( my $val = $enum->nextObject() ) {
        last unless ( $$val );
        print $count++, "\n";
        # print Dumper( $key );
        list_keys( $val, @subkeys );
    }
}



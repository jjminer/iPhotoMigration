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

package PlistDictionary;

use Foundation;

sub perlValue {
    my $object = shift;
    return $object->description()->UTF8String();
}

sub TIEHASH {
    my $self = shift;

    my $arg = shift;

    my $dict = {};

    if ( ! ref($arg) ) {
        die( "file not found, dumbass." ) unless ( -r $arg );

        $dict->{plist_file} = $arg,

        $dict->{plist} = NSDictionary->dictionaryWithContentsOfFile_( $dict->{plist_file} );
    }
    elsif ( ref($arg) eq 'NSCFDictionary' ) {
        $dict->{plist} = $arg;
    }

    die( "argument must be specified." ) unless ( $dict->{plist} );

    return bless $dict, $self;
}

sub FETCH {

    my $self = shift;
    my $key = shift;

    my $val = $self->{plist}->objectForKey_( $key );

    if ( ref($val) eq 'NSCFDictionary' ) {
        tie my %tmp, __PACKAGE__, $val;
        return tied %tmp;
    }
    elsif ( ref($val) eq 'NSCFArray' ) {
        return ref($val);
    }

    return perlValue( $val );
}

sub STORE {
    die( __PACKAGE__, ": STORE not implemented." );
}

sub DELETE {
    die( __PACKAGE__, ": DELETE not implemented." );
}

sub CLEAR {
    die( __PACKAGE__, ": CLEAR not implemented." );
}

sub EXISTS {
    my $self = shift;
    my $key = shift;

    my $tmp = $self->{plist}->objectForKey_( $key );

    return 1 == 0 if (
        !defined( $tmp )
        || !defined( $$tmp )
        || !ref($$tmp)
    );

    return 1 == 1;
}

my $key_enum = undef;

sub FIRSTKEY {
    my $self = shift;

    $key_enum = $self->{plist}->keyEnumerator();

    my $val = $key_enum->nextObject;

    return unless ( $$val );

    return perlValue($val);
}

sub NEXTKEY {
    my $self = shift;

    die ( "no enumerator?" ) unless ( $key_enum );

    my $val = $key_enum->nextObject;

    return unless ( $$val );

    return perlValue($val);
}

1;

package main;

# WTF? use strict;
use Data::Dumper;

tie my %iphoto_library, PlistDictionary, 'AlbumData.xml';

foreach my $key ( keys %iphoto_library ) {
    my $val = $iphoto_library{$key};
    # print "Key: ", perlValue( $key ), ' : ', $val ? ref($val) eq 'NSCFArray' || ref($val) eq 'NSCFDictionary' ? ref($val) : perlValue( $val ) : 'UHHH...', "\n";
    print "$key: $iphoto_library{$key}\n";
}

## Dammit, doesn't work.  Need to implement as non-tied, I guess.

print "--- Keywords ---\n";

foreach my $key ( keys %{$iphoto_library{'List of Keywords'}} ) {
    print "$key: ", $iphoto_library{'List of Keywords'}->{$key}, "\n";
}

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



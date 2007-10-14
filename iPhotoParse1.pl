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
use Data::Dumper;

use Foundation;

my $iphoto_library = NSDictionary->dictionaryWithContentsOfFile_('AlbumData.xml');

print Dumper( $iphoto_library );

my $crp = $iphoto_library->objectForKey_( 'Crap' );

if ( defined($crp) ) {
    print "CRP defined [", ref $crp, "]?\n";

    if ( defined($$crp) ) {
        print "\$\$CRP defined [$$crp]?\n";
    }
}

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

sub perlValue {
    my $object = shift;
    return $object->description()->UTF8String();
}



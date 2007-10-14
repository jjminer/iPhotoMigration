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
use Mac::PropertyList;

use Data::Dumper;

my $file = shift;
my $max_depth = shift || 0;

my $plist = new Mac::PropertyList(
    file => $file || 'AlbumData.xml',
);

my $depth = 0;

list_plist( $plist );

sub list_plist {
    my $plist = shift;

    return if ( $depth > $max_depth );

    $depth++;

    if ( ref($plist) eq 'Mac::PropertyList::dict' ) {

        foreach my $key ( $plist->keys ) {
            my $val = $plist->get($key);
            print ' ' x ($depth -1 ), "$key: $val\n";

            list_plist( $val ) if ( ref( $val ) );
        }

    }
    elsif ( ref($plist) eq 'Mac::PropertyList::array' ) {

        while ( my $val = $plist->next_entry ) {
            print ' ' x ($depth - 1), "$val\n";

            list_plist( $val ) if ( ref( $val ) );
        }

    }

    $depth--;

}

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
use Mac::PropertyList::Foundation;

package iPhotoLibrary;

use Mac::PropertyList::Foundation;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = @_;

    my $self = bless {}, $class;

    if ( $params{file} ) {

        return $self->load( $params{file} );
    }

    return $self;
}


sub load {
    my $self = shift;

    unless ( ref($self) ) {
        return iPhotoLibrary->new( file => $self );
    }
    my $file = shift;

    my $lib = $self->{plist} = new Mac::PropertyList::Foundation(
        file => $filename
    );

    # Load up the images
    #
    # First so we can update each record with the Album/Roll info as we go.

    while ( my $key = $iphoto_library->get( 'Master Image List' )->next_entry ) {
        $self->{images}->{$key} = new iPhotoLibrary::Album(
            library => $self,
            plist => $val,
        );
    }

    # Load up the rolls

    while ( my $val = $iphoto_library->get( 'List of Rolls' )->next_entry ) {
        $self->{rolls}->{$val->get( 'AlbumId' )} = new iPhotoLibrary::Album(
            library => $self,
            plist => $val,
        );
    }

    # Load up the albums

    while ( my $val = $iphoto_library->get( 'List of Albums' )->next_entry ) {
        $self->{albums}->{$val->get( 'AlbumId' )} = new iPhotoLibrary::Album(
            library => $self,
            plist => $val,
        );
    }

}

1;

package iPhotoLibrary::Album;

sub new {
}

1;

package iPhotoLibrary::Item;

# Need to handle the orignal vs modified path issue.

1;

package iPhotoLibrary::Roll;

1;

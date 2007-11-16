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

use vars qw/$BASE_TIME/;

$BASE_TIME = timegm( 0, 0, 0, 1, 1, 2001 );

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = @_;

    my $self = bless {}, $class;

    if ( $params{file} ) {

        $self->load( $params{file} );
    }

    return $self;
}


sub load {
    my $self = shift;

    unless ( ref($self) ) {
        return iPhotoLibrary->new( file => $self );
    }
    my $file = shift;

    my $iphoto_library = $self->{plist} = new Mac::PropertyList::Foundation(
        file => $file
    );

    my $lok = $iphoto_library->get('List of Keywords');
    foreach my $key ( $lok->keys ) {
        $self->{keywords}->{$key} = $lok->get( $key );
    }

    # Load up the images
    #
    # First so we can update each record with the Album/Roll info as we go.

    while ( my $key = $iphoto_library->get( 'Master Image List' )->next_key ) {
        $self->{images}->{$key} = new iPhotoLibrary::Item(
            library => $self,
            plist => $iphoto_library->get( 'Master Image List' )->get( $key ),
            id => $key,
        );
    }

    # Load up the rolls

    while ( my $val = $iphoto_library->get( 'List of Rolls' )->next_entry ) {
        $self->{rolls}->{$val->get( 'RollID' )} = new iPhotoLibrary::Roll(
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
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = @_;

    my $self = bless {}, $class;

    $self->{library} = $params{library};

    return $self;
}

my %alb_keys = (
    AlbumID => 'ID',
    PhotoCount => 'PhotoCount',
    AlbumName => 'Name',
    Comments => 'Comments',
    Parent => 'Parent',
    'Album Type' => 'Type',
);

sub load {
    my $self = shift;
    my $plist = shift;

    foreach my $key ( keys %alb_keys ) {
        next unless ( defined( $plist->get( $key ) ) );
        $self->{ $alb_keys{$key} } = $plist->get( $key );
    }

    # Load Photo IDs, cross-reference to photos themselves.

    if (
        defined($plist->get( 'Album Type' ))
        && $plist->get( 'Album Type' ) eq 'Regular'
    ) {
        foreach my $key ( $plist->get( 'KeyList' )->values ) {
            $self->{library}->{images}->{$key}->add_album( $self->{ID} );
        }
    }
}

1;

package iPhotoLibrary::Item;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = @_;

    my $self = bless {}, $class;

    $self->{library} = $params{library};

    if ( $params{id} ) {
        $self->{ID} = $params{id};
    }

    if ( $params{plist} ) {
        $self->load($params{plist});
    }

    return $self;
}

my %image_keys = (
    ModDateAsTimerInterval => [ 'ModDate', 'Date' ],
    OriginalPath => undef,
    ImagePath => undef,
    MetaModDate => [ 'MetaModDate', 'Date' ],
    Comment => undef,
    MediaType => undef,
    Date => [ 'Date', 'Date' ],
    Rating => undef,
    Caption => undef,
    Keywords => [ 'Keywords', 'Array' ],
    JpegIsCacheForRAW => [ 'RAW', undef ],
    RotationIsOnlyEdit => [ 'RotatedOnly', undef ],
    Roll => undef,
);

# Need to handle the orignal vs modified path issue.

sub load {
    my $self = shift;
    my $plist = shift;

    foreach my $key ( keys %image_keys ) {
        next unless ( defined( $plist->get( $key ) ) );

        if ( !defined( $image_keys{$key} ) ) {
            $self->{$key} = $plist->get( $key );
        } else {
            if ( !defined($image_keys{$key}->[1]) ) {
                $self->{$image_keys{$key}->[0]} = $plist->get( $key );
            } elsif ( $image_keys{$key}->[1] eq 'Array' ) {
                $self->{$image_keys{$key}->[0]} = [ $plist->get( $key )->values ];
            } elsif ( $image_keys{$key}->[1] eq 'Date' ) {
                $self->{$image_keys{$key}->[0]} = $iPhotoLibrary::BASE_TIME + $plist->get( $key );
            } else {
                die( "Unexpected values for key $key!" );
            }
        }
    }

}

sub add_album {
    my $self = shift;
    my $albumid = shift;
    
    push @{$self->{Album}}, $albumid;
}

sub add_roll {
    my $self = shift;
    my $rollid = shift;

    if ( defined($self->{Roll}) && $self->{Roll} != $rollid ) {
        carp( "WTF?  Image ", $self->{ID}, " has roll ", $self->{Roll}, " but $rollid claims it.");
    }
}

1;

package iPhotoLibrary::Roll;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = @_;

    my $self = bless {}, $class;

    $self->{library} = $params{library};

    if ( $params{plist} ) {
        $self->load($params{plist});
    }

    return $self;
}

sub load {
    my $self = shift;
    my $plist = shift;

    $self->{ID} = $plist->get( 'RollID' );
    $self->{PhotoCount} = $plist->get( 'PhotoCount' );
    $self->{Name} = $plist->get( 'RollName' );
    $self->{Date} = $iPhotoLibrary::BASE_TIME + $plist->get( 'RollDateAsTimerInterval' );
    $self->{Comments} = $plist->get( 'Comments' );

    # Load Photo IDs, cross-reference to photos themselves.
    foreach my $key ( $plist->get( 'KeyList' )->values ) {
        $self->{library}->{images}->{$key}->add_roll( $self->{ID} );
    }
}

1;

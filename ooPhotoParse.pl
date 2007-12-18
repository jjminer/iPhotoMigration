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

use Time::Local;

use vars qw/$BASE_TIME/;

$BASE_TIME = timegm( 0, 0, 0, 1, 1, 2001 );

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = @_;

    my $self = bless {}, $class;

    $self->{debug} = $params{debug} || 0;

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
    my $count = 0;
    print STDERR "Loading Keywords....";
    foreach my $key ( $lok->keys ) {
        print STDERR "." if ( (++$count % 10) == 0);
        print STDERR $count if ( ($count % 50 ) == 0 );
        $self->{keywords}->{$key} = $lok->get( $key );
    }
    print STDERR ".${count}done\n";

    # Load up the images
    #
    # First so we can update each record with the Album/Roll info as we go.

    print STDERR "Loading Images....";
    $count = 0;
    my $mil = $iphoto_library->get( 'Master Image List' );
    foreach my $key ( $mil->keys ) {
        print STDERR "." if ( (++$count % 100) == 0);
        print STDERR "$count($key)" if ( ($count % 1000 ) == 0 );
        $self->{images}->{$key} = iPhotoLibrary::Item->new(
            library => $self,
            plist => $mil->get( $key ),
            id => $key,
        );
    }
    print STDERR ".${count}done\n";

    # Load up the rolls

    print STDERR "Loading Rolls....";
    $count = 0;
    my $lor = $iphoto_library->get( 'List of Rolls' );
    while ( my $val = $lor->next_entry ) {
        print STDERR "." if ( (++$count % 100) == 0);
        print STDERR $count if ( ($count % 1000 ) == 0 );
        $self->{rolls}->{$val->get( 'RollID' )} = iPhotoLibrary::Roll->new(
            library => $self,
            plist => $val,
        );
    }
    print STDERR ".${count}done\n";

    # Load up the albums

    print STDERR "Loading Albums....";
    $count = 0;
    my $loa = $iphoto_library->get( 'List of Albums' );
    while ( my $val = $loa->next_entry ) {
        print STDERR "." if ( (++$count % 100) == 0);
        print STDERR $count if ( ($count % 1000 ) == 0 );
        $self->{albums}->{$val->get( 'AlbumId' )} = iPhotoLibrary::Album->new(
            library => $self,
            plist => $val,
        );
    }
    print STDERR ".${count}done\n";

}

1;

package iPhotoLibrary::Album;

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

my %alb_keys = (
    AlbumId => 'ID',
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
        my $val = $plist->get( $key );
        # print STDERR "KEY: $key -> $alb_keys{$key} = $val\n";
        next unless ( defined( $val ) );
        $self->{ $alb_keys{$key} } = $val;
    }

    $self->{Items} = [ $plist->get( 'KeyList' )->values ];

    # Load Photo IDs, cross-reference to photos themselves.

    # print STDERR "Album: ", $self->{Name}, "\n";
    # print STDERR "Type: ", $self->{Type}, "\n";
    # print STDERR "ID ", $self->{ID}, "\n";

    # sleep 300;

    if (
        defined($self->{Type})
        && $self->{Type} eq 'Regular'
    ) {
        foreach my $key ( @{$self->{Items}} ) {
            # print STDERR "Album: $key\n";
            $self->{library}->{images}->{$key}->add_album( $self->{ID} );
        }
    }

    if ( defined($self->{Parent}) ) {
        if ( defined( $self->{library}->{albums}->{$self->{Parent}} ) ) {
            $self->{library}->{albums}->{$self->{Parent}}->set_child( $self->{ID} );
        } else {
            print STDERR "Hmm... Got child ", $self->{ID}, " of ", $self->{Parent}, " before parent...\n";
            sleep 10;
        }
    }
}

sub set_child {
    my $self = shift;
    my $childid = shift;

    print STDERR "Adding child album $childid to ", $self->{ID}, "\n";

    push @{$self->{Children}}, $childid;
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

    # print STDERR "Addling album $albumid to ", $self->{ID}, "\n";
    
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
    $self->{Items} = [ $plist->get( 'KeyList' )->values ];

    # Load Photo IDs, cross-reference to photos themselves.
    foreach my $key ( @{$self->{Items}} ) {
        $self->{library}->{images}->{$key}->add_roll( $self->{ID} );
    }
}

1;

package main;

use Data::Dumper;

my $library = new iPhotoLibrary(
    file => 'AlbumData.xml',
    debug => 1,
);

print STDERR "Sleeeping......";

sleep(20);

open DUMP, '>iphotolibrary.dump';
print DUMP Dumper( $library ), "\n";
close DUMP;

1;


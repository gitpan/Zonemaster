package Zonemaster::Zone v0.0.1;

use 5.14.2;
use strict;
use warnings;

use Moose;
use Carp;

use Zonemaster::DNSName;
use Zonemaster::Recursor;

has 'name' => ( is => 'ro', isa => 'Zonemaster::DNSName', required => 1, coerce => 1 );
has 'parent' => ( is => 'ro', isa => 'Maybe[Zonemaster::Zone]', lazy_build => 1 );
has [ 'ns', 'glue' ] => ( is => 'ro', isa => 'ArrayRef[Zonemaster::Nameserver]', lazy_build => 1 );
has 'glue_addresses' => ( is => 'ro', isa => 'ArrayRef[Net::LDNS::RR]', lazy_build => 1 );

###
### Builders
###

sub _build_parent {
    my ( $self ) = @_;

    if ( $self->name eq '.' ) {
        return $self;
    }

    my $pname = Zonemaster::Recursor->parent( '' . $self->name );
    return if not $pname;
    ## no critic (Modules::RequireExplicitInclusion)
    return __PACKAGE__->new( { name => $pname } );
}

sub _build_glue {
    my ( $self ) = @_;
    my @res;

    my $p = $self->parent->query_one( $self->name, 'NS' );
    croak "Failed to get glue" if not defined( $p );

    return Zonemaster::Recursor->get_ns_from( $p );
}

sub _build_ns {
    my ( $self ) = @_;

    if ( $self->name eq '.' ) {    # Root is a special case
        return [ Zonemaster::Recursor->root_servers ];
    }

    my $p;
    foreach my $s ( @{ $self->glue } ) {
        $p = $s->query( $self->name, 'NS' );
        last if defined( $p );
    }
    croak "Failed to get nameservers" if not defined( $p );

    return Zonemaster::Recursor->get_ns_from( $p );
}

sub _build_glue_addresses {
    my ( $self ) = @_;

    my $p = $self->parent->query_one( $self->name, 'NS' );
    croak "Failed to get glue addresses" if not defined( $p );

    return [ $p->get_records( 'a' ), $p->get_records( 'aaaa' ) ];
}

###
### Public Methods
###

sub query_one {
    my ( $self, $name, $type, $flags ) = @_;

    # Return response from the first server that gives one
    foreach my $ns ( @{ $self->ns } ) {
        my $p = $ns->query( $name, $type, $flags );
        return $p if defined( $p );
    }

    return;
}

sub query_all {
    my ( $self, $name, $type, $flags ) = @_;

    return [ map { $_->query( $name, $type, $flags ) } @{ $self->ns } ];
}

sub is_in_zone {
    my ( $self, $name ) = @_;

    if ( not ref( $name ) or ref( $name ) ne 'Zonemaster::DNSName' ) {
        $name = Zonemaster::DNSName->new( $name );
    }

    if ( scalar( @{ $self->name->labels } ) != $self->name->common( $name ) ) {
        return;    # Zone name cannot be a suffix of tested name
    }

    my $p = $self->query_one( "$name", 'SOA' );

    if ( $p->is_redirect ) {
        return;    # Authoritative servers redirect us, so name must be out-of-zone
    }

    my ( $soa ) = $p->get_records( 'SOA' );
    if ( $soa->name eq $self->name ) {
        return 1;
    }
    else {
        return;
    }
} ## end sub is_in_zone

1;

=head1 NAME

Zonemaster::Zone - Object representing a DNS zone

=head1 SYNOPSIS

    my $zone = Zonemaster::Zone->new({ name => 'nic.se' });
    my $packet = $zone->parent->query_one($zone->name, 'NS');

=head1 ATTRIBUTES

=over

=item name

A L<Zonemaster::DNSName> object representing the name of the zone.

=item parent

A L<Zonemaster::Zone> object for this domain's parent domain.

=item ns

A reference to an array of L<Zonemaster::Nameserver> objects for the domain. The list is based on the NS records returned from a query to the first
listed glue server for the domain.

=item glue

A reference to an array of L<Zonemaster::Nameserver> objects for the domain. The list is based on the NS records returned from a query to the first
listed nameserver for the parent domain.

=item glue_addresses

A list of L<Net::LDNS::RR::A> and L<Net::LDNS::RR::AAAA> records returned in the Additional section of an NS query to the first listed nameserver
for the parent domain.

=back

=head1 METHODS

=over 

=item query_one($name[, $type[, $flags]])

Sends (or retrieves from cache) a query for the given name, type and flags sent to the first nameserver in the zone's ns list. If there is a
response, it will be returned in a L<Zonemaster::Packet> object. If the type arguments is not given, it defaults to 'A'. If the flags are not given, they default to C<class> IN and C<dnssec>, C<usevc> and C<recurse> according to configuration (which is by default off on all three).

=item query_all($name, $type, $flags)

Sends (or retrieves from cache) queries to all the nameservers listed in the zone's ns list, and returns a reference to an array with the
responses. The responses can be either L<Zonemaster::Packet> objects or C<undef> values. The arguments are the same as for L<query_one>.

=item is_in_zone($name)

Returns true if the given name is in the zone, false if not.

=back

=cut

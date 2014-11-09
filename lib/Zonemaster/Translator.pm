package Zonemaster::Translator v0.0.5;

use 5.14.2;
use strict;
use warnings;

use Moose;
use Carp;
use Zonemaster;

use POSIX qw[setlocale LC_MESSAGES];
use Locale::TextDomain qw[Zonemaster];

has 'locale' => ( is => 'rw', isa => 'Str',     lazy => 1, builder => '_get_locale' );
has 'data'   => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_load_data' );

###
### Builder Methods
###

sub BUILD {
    my ( $self ) = @_;

    $self->locale;

    return $self;
}

sub _get_locale {
    my $locale = $ENV{LANG} || $ENV{LC_ALL} || $ENV{LC_MESSAGES} || 'en_US.UTF-8';
    setlocale( LC_MESSAGES, $locale );

    return $locale;
}

sub _load_data {
    my %data;

    $data{SYSTEM} = _system_translation();
    foreach my $mod ( 'Basic', Zonemaster->modules ) {
        my $module = 'Zonemaster::Test::' . $mod;
        $data{ uc( $mod ) } = $module->translation();
    }

    return \%data;
}

###
### Method modifiers
###

after 'locale' => sub {
    my ( $self ) = @_;

    setlocale( LC_MESSAGES, $self->{locale} );
};

###
### Working methods
###

sub to_string {
    my ( $self, $entry ) = @_;

    return sprintf( "%7.2f %-9s %s", $entry->timestamp, $entry->level, $self->translate_tag( $entry ) );
}

sub translate_tag {
    my ( $self, $entry ) = @_;

    my $string = $self->data->{ $entry->module }{ $entry->tag };

    if ( not $string ) {
        return $entry->string;
    }

    return __x( $string, %{ $entry->args } );
}

sub _system_translation {
    return {
        "CANNOT_CONTINUE"       => "Not enough data about {zone} was found to be able to run tests.",
        "CONFIG_FILE"           => "Configuration was read from {name}.",
        "DEPENDENCY_VERSION"    => "Using prerequisite module {name} version {version}.",
        "LOGGER_CALLBACK_ERROR" => "Logger callback died with error: {exception}",
        "LOOKUP_ERROR"          => "DNS query to {ns} for {name}/{type}/{class} failed with error: {message}",
        "MODULE_ERROR"          => "Fatal error in {module}: {msg}",
        "MODULE_VERSION"        => "Using module {module} version {version}.",
        "NO_NETWORK"            => "Both IPv4 and IPv6 are disabled.",
        "POLICY_FILE"           => "Policy was read from {name}.",
        "POLICY_DISABLED"       => "The module {name} was disabled by the policy.",
        "UNKNOWN_METHOD"        => "Request to run unknown method {method} in module {module}.",
        "UNKNOWN_MODULE"        => "Request to run {method} in unknown module {module}. Known modules: {known}.",
        "SKIP_IPV4_DISABLED"    => "IPv4 is disabled, not sending query to {ns}.",
        "SKIP_IPV6_DISABLED"    => "IPv6 is disabled, not sending query to {ns}.",
        "FAKE_DELEGATION"       => "Followed a fake delegation.",
        "ADDED_FAKE_DELEGATION" => "Added a fake delegation for domain {domain} to name server {ns}.",
        "FAKE_DELEGATION_TO_SELF" => "Name server {ns} not adding fake delegation for domain {domain} to itself.",
    };
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Zonemaster::Translator - translation support for Zonemaster

=head1 SYNOPSIS

    my $trans = Zonemaster::Translator->new({ lang => 'tech' });
    say $trans->to_string($entry);

=head1 ATTRIBUTES

=over

=item locale

The locale that should be used to find translation data.

=item data

A reference to a hash with translation data. This is unlikely to be useful to
end-users.

=back

=head1 METHODS

=over

=item to_string($entry)

Takes a L<Zonemaster::Logger::Entry> object as its argument and returns a translated string with the timestamp, level, message and arguments in the
entry.

=item translate_tag

Takes a L<Zonemaster::Logger::Entry> object as its argument and returns a translation of its tag and arguments.

=item BUILD

Internal method that's only mentioned here to placate L<Pod::Coverage>.

=back

=cut

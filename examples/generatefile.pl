#!/usr/bin/perl
#
# This file is part of Task-POE-All
#
# This software is copyright (c) 2014 by Apocalypse.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict; use warnings;
use strict; use warnings;

# run this like: perl examples/generatefile.pl > lib/Task/POE/All.pm

# we use CPANPLUS to search!
use CPANPLUS::Backend;
use CPANPLUS::Configure;

# silence CPANPLUS!
{
	no warnings 'redefine';
	sub Log::Message::Handlers::cp_msg { return };
	sub Log::Message::Handlers::cp_error { return };
}

# Okay, get all the distributions that are POE :)
# init the backend ( and set some options )
my $conf = CPANPLUS::Configure->new;
$conf->set_conf( 'verbose' => 0 );
$conf->set_conf( 'no_update' => 1 );

# ARGH, CPANIDX doesn't work well with this kind of search...
if ( $conf->get_conf( 'source_engine' ) =~ /CPANIDX/ ) {
	warn "Disabling CPANIDX for CPANPLUS";
	$conf->set_conf( 'source_engine' => 'CPANPLUS::Internals::Source::Memory' );
}

# search for matching modules/packages
my $cb = CPANPLUS::Backend->new( $conf );
my @mods = $cb->search( 'type' => 'module', 'allow' => [ qr/^POEx?::/ ] );

# collate the data
my %seen;
foreach my $m ( @mods ) {
	# is the module name == package name?
	my $pkg = $m->package_name; $pkg =~ s/-/::/g;
	if ( $m->name eq $pkg ) {
		$seen{ $m->package_name } = $m;
		next;
	}

	if ( exists $seen{ $m->package_name } ) {
		# is this module "shorter" in length?
		if ( length( $seen{ $m->package_name }->module ) > length( $m->module ) ) {
			# do a sane version compare so we actually are able to list it as prereq!
			if ( $cb->_vcmp( $m->version, 0 ) ) {
				$seen{ $m->package_name } = $m;
			}
		}
	} else {
		# first hit!
		$seen{ $m->package_name } = $m;
	}
}

# invert the sense of the hash to prepare for prereq
%seen = map { $_->module => $_->version } values %seen;

# Now, dump it!
my $string = <<'EOF';
package Task::POE::All;

# ABSTRACT: All of POE on CPAN

1;
=pod

=head1 SYNOPSIS

	die 'Not meant to be used directly';

=head1 DESCRIPTION

This task contains all distributions under the L<POE> namespace.
EOF

$string .= pkgroup( 'Servers', qr/^POE::Component::Server::/ );
$string .= pkgroup( 'Clients', qr/^POE::Component::Client::/ );
$string .= pkgroup( 'Generic Components', qr/^POE::Component::/ );
$string .= pkgroup( 'Data Parsers and Wheels', qr/^POE::(?:Filter|Wheel)::/ );
$string .= pkgroup( 'Event Loops', qr/^POE::Loop::/ );
$string .= pkgroup( 'Session Types', qr/^POE::Session::/ );
$string .= pkgroup( 'Debugging and Developing POE', qr/^POE::(?:API|Devel|Test|XS)::/ );
$string .= pkgroup( 'POE Extensions', qr/^POEx::/ );
$string .= pkgroup( 'Uncategorized', qr/.+/ );

$string .= "\n=cut\n";

# Write it out!
print $string;

exit;

sub pkgroup {
	my( $header, $re ) = @_;

	my $str = "\n=pkgroup $header\n\n";
	foreach my $s ( grep { $_ =~ $re } sort keys %seen ) {
		$str .= "=pkg $s $seen{$s}\n\n";
		delete $seen{$s}; # so our final catch-all will work!
	}

	return $str;
}
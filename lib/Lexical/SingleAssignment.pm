#!/usr/bin/perl

package Lexical::SingleAssignment;

use strict;
use warnings;
use B::Hooks::OP::Check;
use B::Hooks::EndOfScope;
use namespace::clean;

our $VERSION = "0.06";

eval {
	require XSLoader;
	XSLoader::load(__PACKAGE__, $VERSION);
	1;
} or do {
	require DynaLoader;
	push our @ISA, 'DynaLoader';
	__PACKAGE__->bootstrap($VERSION);
};

sub import {
    my ($class) = @_;

    push our @hooks, $class->setup;

    on_scope_end {
        $class->teardown(pop @hooks);
    };
}

sub unimport {
    my ($class) = @_;

	if ( our @hooks ) {
		$class->teardown(pop @hooks);

		on_scope_end {
			push @hooks, $class->setup;
		};
	}
}

sub setup {
	my $class = shift;

	my %ret = map {
		/^setup_(.*)/ ? ( $1 => $class->$_ ) : ()
	} keys %Lexical::SingleAssignment::;

	\%ret;
}

sub teardown {
	my ( $class, $hooks ) = @_;

	foreach my $hook ( keys %$hooks ) {
		my $teardown = "teardown_$hook";
		$class->$teardown($hooks->{$hook});
	}
}

__PACKAGE__

__END__


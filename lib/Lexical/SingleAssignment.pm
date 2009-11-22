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
    my $caller = caller;

    my $hooks = $class->setup;

    on_scope_end {
        $class->teardown($hooks);

		if ( defined our $error ) {
			my $copy = $error;
			undef $error;
			$copy .= " (previous error: $@)\n" if $@;
			die $copy;
		}
    };

    return;
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


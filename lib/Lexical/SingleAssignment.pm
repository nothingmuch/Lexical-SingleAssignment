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

=pod

=head1 NAME

Lexical::SingleAssignment - Single assignment lexical variables

	{
		# lexically scoped, like use strict
		use Lexical::SingleAssignment;


		# declare a lexical normally and give it a value
		my $x = "Foo";


		# compile time error, no initial value provided
		my $y;


		# compile time error, assignment after declaration
		$x = "bar";


		# runtime error, read only variable
		my $ref = \$x;
		$$ref = "bar";


		{
			no Lexical::SingleAssignment;


			# runtime error, $x is still readonly from parent scope
			$x = "bar";


			# no error, module not in enabled in this scope
			my $inner;
			$inner = 3;
		}
	}

=head1 DESCRIPTION

This module implements lexically scoped single assignment lexicals.

When this module is in scope all lexical variables must be assigned a value at
their declaration site, and cannot be modified afterwords.

In other words, when this module is in effect all lexicals must be assigned to
exactly once, whereas normally you may assign zero or more times.

This is somewhat similar to immutable name bindings in other languages, but the
SVs created are still copies (they are just readonly copies).

=cut

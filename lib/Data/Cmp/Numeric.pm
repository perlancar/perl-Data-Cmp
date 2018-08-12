package Data::Cmp::Numeric;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Scalar::Util qw(blessed reftype refaddr);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(cmp_data);

our $EPSILON;

# for when dealing with circular refs
my %_seen_refaddrs;

sub _cmp_data {
    my $d1 = shift;
    my $d2 = shift;

    my $def1 = defined $d1;
    my $def2 = defined $d2;
    if ($def1) {
        return 1 if !$def2;
    } else {
        return $def2 ? -1 : 0;
    }

    # both are defined

    my $reftype1 = reftype($d1);
    my $reftype2 = reftype($d2);
    if (!$reftype1 && !$reftype2) {
        if (defined $EPSILON && abs($d1 - $d2) < $EPSILON) {
            return 0;
        } else {
            return $d1 <=> $d2;
        }
    } elsif ( $reftype1 xor $reftype2) { return 2 }

    # both are refs

    return 2 if $reftype1 ne $reftype2;

    # both are refs of the same type

    my $pkg1 = blessed($d1);
    my $pkg2 = blessed($d2);
    if (defined $pkg1) {
        return 2 unless defined $pkg2 && $pkg1 eq $pkg2;
    } else {
        return 2 if defined $pkg2;
    }

    # both are non-objects or objects of the same class

    my $refaddr1 = refaddr($d1);
    my $refaddr2 = refaddr($d2);

    if ($reftype1 eq 'ARRAY' && !$_seen_refaddrs{$refaddr1} && !$_seen_refaddrs{$refaddr2}) {
        $_seen_refaddrs{$refaddr1}++;
        $_seen_refaddrs{$refaddr2}++;
      ELEM:
        for my $i (0..$#{$d1}) {
            if ($i > $#{$d2}) { return 1 }
            my $cmpres = _cmp_data($d1->[$i], $d2->[$i]);
            return $cmpres if $cmpres;
        }
        if (@$d2 > @$d1) { return -1 }
        return 0;
    } elsif ($reftype1 eq 'HASH' && !$_seen_refaddrs{$refaddr1} && !$_seen_refaddrs{$refaddr2}) {
        $_seen_refaddrs{$refaddr1}++;
        $_seen_refaddrs{$refaddr2}++;
        my $nkeys1 = keys %$d1;
        my $nkeys2 = keys %$d2;
      KEY:
        for my $k (sort keys %$d1) {
            unless (exists $d2->{$k}) { return $nkeys1 <=> $nkeys2 || 2 }
            my $cmpres = _cmp_data($d1->{$k}, $d2->{$k});
            return $cmpres if $cmpres;
        }
        return $nkeys1 <=> $nkeys2;
    } else {
        return $refaddr1 == $refaddr2 ? 0 : 2;
    }
}

sub cmp_data {
    my $d1 = shift;
    my $d2 = shift;

    %_seen_refaddrs = ();
    _cmp_data($d1, $d2);
}

1;
# ABSTRACT: Compare two data structures, return -1/0/1 like <=>

=head1 SYNOPSIS

 use Data::Cmp::Numeric qw(cmp_data);

 cmp_data([0, 1, 10], [0, 1, 9]);                       # =>  1

Contrasted with L<Data::Cmp>:

 use Data::Cmp ();
 Data::Cmp::cmp_data([0, 1, 10], [0, 1, 9]);            # => -1

Perform numeric comparison with some tolerance:

 {
     local $Data::Cmp::Numeric::EPSILON = 1e-3;
     cmp_data(1, 1.1   );     # -1
     cmp_data(1, 1.0001);     #  0
     cmp_data([1], [1.0001]); #  0
 }


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 cmp_data

Usage:

 cmp_data($d1, $d2) => -1/0/1/2

This module's C<cmp_data()> is just like L<Data::Cmp>'s except that two defined
non-reference values are compared using Perl's C<< <=> >> instead of C<cmp>.


=head1 VARIABLES

=head2 $EPSILON

Can be set to perform numeric comparison with some tolerance. See example in
Synopsis.


=head1 SEE ALSO

L<Data::Cmp>

L<Data::Cmp::StrOrNumeric>

=cut

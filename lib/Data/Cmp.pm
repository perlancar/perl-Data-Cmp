package Data::Cmp;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Scalar::Util qw(looks_like_number blessed reftype refaddr);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(cmp_data);

# for when dealing with circular refs
our %_seen_refaddrs;

sub _cmp_data {
    my ($d1, $d2) = @_;

    my $cmpres;

    my $def1 = defined $d1;
    my $def2 = defined $d2;
    if    ( $def1 && !$def2) { return 1 }
    elsif (!$def1 &&  $def2) { return -1 }
    elsif (!$def1 && !$def2) { return 0 }

    # both are defined

    my $reftype1 = reftype($d1);
    my $reftype2 = reftype($d2);
    if    ( $reftype1 xor $reftype2) { return 2 }
    elsif (!$reftype1 && !$reftype2) {
        return $d1 cmp $d2;
    }

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
    my ($d1, $d2) = @_;

    local %_seen_refaddrs = ();
    _cmp_data($d1, $d2);
}

1;
# ABSTRACT: Compare two data structures, return -1/0/1 like cmp

=head1 SYNOPSIS

 use Data::Cmp qw(cmp_data);

 cmp_data(["one", "two", "three"],
          ["one", "two", "three"]); # => 0

 cmp_data(["one", "two" , "three"],
          ["one", "two2", "three"]); # => -1

 cmp_data(["one", "two", "three"],
          ["one", "TWO", "three"]); # => 1

 # hash/array is not "comparable" with scalar
 cmp_data(["one", "two", {}],
          ["one", "two", "three"]); # => 2

Sort data structures (of similar structures):

 use Data::Cmp qw(cmp_data);
 use Data::Dump;
 my @arrays = ([3], [1], [-1, 2], [0,0], [1,2]);
 dd sort { cmp_data($a, $b) } @arrays;


=head1 DESCRIPTION

This relatively compact module offers the C<cmp_data> function that, like Perl's
C<cmp>, returns -1/0/1 value. In addition to that, it can also return 2 if the
two data structures differ but there is no sensible notion of which one is
"greater than" the other.

This module can handle circular structure.

The following are the rules of comparison used by C<cmp_data()>:

=over

=item * Two undefs are the same (0)

=item * A defined value is greater than (1) undef

=item * Two non-reference scalars are compared string-wise using Perl's cmp

=item * A reference and non-reference are different (2)

=item * Two references that are of different types are different (2)

=item * Blessed references that are blessed into different packages are different (2)

=item * Array references are compared element by element

=item * A longer array is greater than (1) its shorter subset

=item * Hash references are compared key by key

=item * When two hash references share a common subset of pairs, the greater is the one that has more non-common pairs

=back


=head1 FUNCTIONS

=head2 cmp_data

Usage:

 cmp_data($d1, $d2) => -1/0/1/2


=head1 SEE ALSO

Other variants of Data::Cmp: L<Data::Cmp::Custom> (allows custom actions and
comparison routines), L<Data::Cmp::Diff> (generates diff structure instead of
just returning -1/0/1/2), L<Data::Cmp::Diff::Perl> (generates diff in the form
of Perl code).

Modules that just return boolean result ("same or different"): L<Data::Compare>,
L<Test::Deep::NoTest> (offers flexibility or approximate or custom comparison).

Modules that return some kind of "diff" data: L<Data::Comparator>,
L<Data::Diff>.

Of course, to check whether two structures are the same you can also serialize
each one then compare the serialized strings/bytes. There are many modules for
serialization: L<JSON>, L<YAML>, L<Sereal>, L<Data::Dumper>, L<Storable>,
L<Data::Dmp>, just to name a few.

Test modules that do data structure comparison: L<Test::DataCmp> (test module
based on Data::Cmp::Custom), L<Test::More> (C<is_deeply()>), L<Test::Deep>,
L<Test2::Tools::Compare>.

=cut

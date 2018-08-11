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
    my ($d1, $d2, $opts, $ctx) = @_;

    if ($opts->{cmp}) {
        my $cmpres = $opts->{cmp}->($d1, $d2, $ctx);
        return $cmpres if defined $cmpres;
    }

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
        my $llnum1 = looks_like_number($d1);
        my $llnum2 = looks_like_number($d2);
        if ($llnum1 && $llnum2) {
            if ($opts->{num_cmp}) {
                my $cmpres = $opts->{num_cmp}->($d1, $d2, $ctx);
                return $cmpres if defined $cmpres;
            }
            if ($opts->{tolerance}) {
                my $delta = abs($d1 - $d2);
                if ($delta < $opts->{tolerance}) {
                    return 0;
                } else {
                    return $d1 <=> $d2;
                }
            } else {
                return $d1 <=> $d2;
            }
        } else {
            if ($opts->{str_cmp}) {
                my $cmpres = $opts->{str_cmp}->($d1, $d2, $ctx);
                return $cmpres if defined $cmpres;
            }
            if ($opts->{ci}) {
                return lc($d1) cmp lc($d2);
            } else {
                return $d1 cmp $d2;
            }
        }
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
        local $ctx->{depth} = $ctx->{depth} + 1;
        local $ctx->{index} = -1;
      ELEM:
        for my $i (0..$#{$d1}) {
            if ($i > $#{$d2}) { return 1 }
            $ctx->{index} = $i;
            if ($opts->{elem_cmp}) {
                my $cmpres = $opts->{elem_cmp}->($d1->[$i], $d2->[$i], $ctx);
                if (defined $cmpres) {
                    next ELEM if $cmpres == 0;
                    return $cmpres;
                }
            }
            my $cmpres = _cmp_data($d1->[$i], $d2->[$i], $opts, $ctx);
            return $cmpres if $cmpres;
        }
        if (@$d2 > @$d1) { return -1 }
        return 0;
    } elsif ($reftype1 eq 'HASH' && !$_seen_refaddrs{$refaddr1} && !$_seen_refaddrs{$refaddr2}) {
        $_seen_refaddrs{$refaddr1}++;
        $_seen_refaddrs{$refaddr2}++;
        local $ctx->{depth} = $ctx->{depth} + 1;
        local $ctx->{key} = undef;
        my $nkeys1 = keys %$d1;
        my $nkeys2 = keys %$d2;
      KEY:
        for my $k (sort keys %$d1) {
            unless (exists $d2->{$k}) { return $nkeys1 <=> $nkeys2 || 2 }
            $ctx->{key} = $k;
            if ($opts->{elem_cmp}) {
                my $cmpres = $opts->{elem_cmp}->($d1->{$k}, $d2->{$k}, $ctx);
                if (defined $cmpres) {
                    next ELEM if $cmpres == 0;
                    return $cmpres;
                }
            }
            my $cmpres = _cmp_data($d1->{$k}, $d2->{$k}, $opts, $ctx);
            return $cmpres if $cmpres;
        }
        return $nkeys1 <=> $nkeys2;
    } else {
        return $refaddr1 == $refaddr2 ? 0 : 2;
    }
}

sub cmp_data {
    my ($d1, $d2, $opts) = @_;
    $opts //= {};

    local %_seen_refaddrs = ();
    my $ctx = {depth => 0};
    _cmp_data($d1, $d2, $opts, $ctx);
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

 # case insensitive string comparison
 cmp_data(["one", "two", "three"],
          ["one", "TWO", "three"], {ci=>1}); # => 0

 # approximate number comparison
 cmp_data([1, 1.5    , 1.6],
          [1, 1.49999, 1.6], {epsilon=>1e-4}); # => 0

 cmp_data(["one", "two", {}],
          ["one", "TWO", "three"]); # => 1

 # hash/array is not "comparable" with scalar
 cmp_data(["one", "two", {}],
          ["one", "two", "three"]); # => 2

 # so is hash and array
 cmp_data([],
          {}); # => 2

 # custom comparison function: always return the same
 cmp_data(["one" , "two", "three"],
          ["satu", "dua", 3], {elem_cmp=>sub {0}}); # => 0

 # custom comparison function: compare length ("satu" is longer than "one")
 cmp_data(["one" , "two", "three"],
          ["satu", "dua", "tiga" ], {elem_cmp=>sub { length $_[0] <=> length $_[1] }}); # => -1


=head1 DESCRIPTION

This module offers the C<cmp_data> function that can compare two data structures
in a flexible manner. The function can return a ternary value -1/0/1 like Perl's
C<cmp> or C<< <=> >> operator (or another value 2, if the two data structures
differ but there is no sensible notion of which one is larger than the other).

This module can handle circular structure.

This module offers an alternative to L<Test::Deep> (specifically,
L<Test::Deep::NoDeep>'s C<is_deeply()>). Test::Deep allows customizing
comparison on specific points in a data structure, while Data::Cmp's
C<cmp_data()> is more geared towards customizing comparison behavior across all
points in a data structure. Depending on your need, one might be more convenient
than the other.

For basic customization, you can turn on case-sensitive matching or numeric
tolerance. For more advanced customization, you can provide coderefs to perform
comparison of data items yourself.


=head1 FUNCTIONS

=head2 cmp_data

Usage:

 cmp_data($d1, $d2 [ , \%opts ]) => -1|0|1|2

Compare two data structures C<$d1> and C<$d2> recursively. Like the C<cmp>
operator, will return either: 0 if the two structures are equivalent, -1 if
C<$d1> is "less than" C<$d2>, 1 if C<$d1> is "greater than" C<$d2>. Unlike the
C<cmp> operator, can also return 2 if C<$d1> and C<$d2> differ but there is no
sensible notion of which one is "greater than" the other.

Can detect recursive references.

Default behavior when comparing different types of data:

=over

=item * Two undef values are the same (0)

 cmp_data(undef, undef); # 0

=item * Defined value is greater than undefined value

 cmp_data(undef, 0); # -1

=item * Two numbers will be compared using Perl's C<< <=> >> operator

Whether data is a number will be determined using L<Scalar::Util>'s
C<looks_like_number>.

 cmp_data("10", 9); # 1

=item * Strings or number vs string will be compared using Perl's C<cmp> operator

 cmp_data("a", "2b"); # 1

=item * A reference is different from a non-reference value

 cmp_data(1, \1); # 2

=item * Two references are different when they are of different type (e.g. HASH and ARRAY)

 cmp_data([], {}); # 2

=item * Two references are different when one is blessed and the other is not

 cmp_data([], blessed([], "foo")); # 2

=item * Two blessed references are different when the packages they are blessed into are different

 cmp_data(bless([], "foo"), bless([], "bar")); # 2
 cmp_data(bless([], "foo"), bless([], "foo")); # 0

=item * Two arrays will be compared element by element

If all elements are the same until the last element of the shorter array, the
longer array is greater than the shorter one.

 cmp_data([1,2,3], [1,3,2]); # -1

 cmp_data([1,2,3], [1,2]); # 1
 cmp_data([1,2,3], [1,2,3,0]); # -1

=item * Two hashes will be compared key by key (sorted ascibetically)

If after all common keys are compared all values are the same, the hash with
more extra keys are greater than the other one; if they have the same number of
extra keys, they are different; if they both have no extra keys, they are the
same.

 cmp_data({a=>1, b=>2}, {a=>1, b=>2}); # 0
 cmp_data({a=>1, b=>2}, {a=>1, b=>3}); # -1

 cmp_data({a=>1, b=>2}, {a=>1}); # 1
 cmp_data({a=>1, b=>2}, {a=>1, c=>1}); # 2

 cmp_data({a=>1, b=>2}, {a=>1, c=>1, d=>1}); # -1

=item * Non-hash and non-array references are the same only if they have the same address

 cmp_data(\1, \1); # 2
 my $ref = \1; cmp_data($ref, $ref); # 0

=back

Known options:

=over

=item * ci

Boolean. Can be set to true to turn on case-insensitive string comparison.

=item * tolerance

Float. Can be set to perform numeric comparison with some tolerance.

=item * cmp

Coderef. Can be set to provide custom comparison routine.

The coderef will be called for every data item (container included e.g. hash and
array, before diving down to their items) and given these arguments:

 ($item1, $item2, \%context)

Context contains these keys: C<depth> (int, starting from 0 from the topmost
level).

Must return 0, -1, 1, or 2. You can also return undef if you want to decline
doing comparison. In that case, C<cmp_data()> will use its default comparison
logic.

When using this option, C<ci> and C<tolerance> options do not take effect.

=item * elem_cmp

Coderef. Just like C<cmp> option, except this routine will only be consulted for
array elements or hash pair value.

=item * num_cmp

Coderef. Just like C<cmp> option, except this routine will only be consulted two
compared two defined numbers.

=item * str_cmp

Coderef. Just like C<cmp> option, except this routine will only be consulted two
compared two defined strings.

=back


=head1 SEE ALSO

Modules that just return boolean result ("same or different"): L<Data::Compare>,
L<Test::Deep::NoTest> (offers flexibility or approximate or custom comparison).

Modules that return some kind of "diff" data: L<Data::Comparator>,
L<Data::Diff>.

Of course, to check whether two structures are the same you can also serialize
each one then compare the serialized strings/bytes. There are many modules for
serialization: L<JSON>, L<YAML>, L<Sereal>, L<Data::Dumper>, L<Storable>,
L<Data::Dmp>, just to name a few.

Test modules that do data structure comparison: L<Test::DataCmp> (test module
based on Data::Cmp), L<Test::More> (C<is_deeply()>), L<Test::Deep>,
L<Test2::Tools::Compare>.

=cut

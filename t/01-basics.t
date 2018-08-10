#!perl

use 5.010001;
use strict;
use warnings;
use Test::More 0.98;

use Data::Cmp qw(cmp_data);

subtest undef => sub {
    is(cmp_data(undef, undef), 0);
    is(cmp_data(undef, 0), -1);
    is(cmp_data(0, undef), 1);
};

subtest num => sub {
    is(cmp_data(1, 1), 0);
    is(cmp_data(1.1, 1.1), 0);
    is(cmp_data("1.1", 1.1), 0);
    is(cmp_data(1, 1.0001), -1);
    is(cmp_data(1, -1.0001), 1);
};

subtest "opt:tolerance" => sub {
    is(cmp_data(1, 1.0001, {tolerance=>1e-3}), 0);
    is(cmp_data(1, 1.0005, {tolerance=>1e-4}), -1);
    is(cmp_data([1], [1.0001], {tolerance=>1e-3}), 0);
    is(cmp_data({a=>1}, {a=>1.0001}, {tolerance=>1e-3}), 0);
};

subtest str => sub {
    is(cmp_data("", ""), 0);
    is(cmp_data("abc", "abc"), 0);
    is(cmp_data("abc", "ab"), 1);
    is(cmp_data("Abc", "abc"), -1);
};

subtest "opt:ci" => sub {
    is(cmp_data("Abc", "abc", {ci=>1}), 0);
    is(cmp_data(["Abc"], ["abc"], {ci=>1}), 0);
    is(cmp_data({a=>"Abc"}, {a=>"abc"}, {ci=>1}), 0);
};

subtest ref => sub {
    is(cmp_data([], 0), 2);
    is(cmp_data(0, []), 2);
    is(cmp_data([], {}), 2);
};

subtest obj => sub {
    is(cmp_data(bless([], "foo"), bless([], "bar")), 2);
    is(cmp_data(bless([], "foo"), bless([], "foo")), 0);
};

subtest array => sub {
    is(cmp_data([], []), 0);
    is(cmp_data([0], []), 1);
    is(cmp_data([0], [0,0]), -1);
    is(cmp_data([1], [0,0]), 1);
};

subtest hash => sub {
    is(cmp_data({}, {}), 0);
    is(cmp_data({a=>1}, {}), 1);
    is(cmp_data({a=>1}, {a=>1}), 0);
    is(cmp_data({a=>1}, {a=>1, b=>2}), -1);
    is(cmp_data({a=>1, c=>3, d=>4}, {a=>1, b=>2}), 1);
    is(cmp_data({a=>1}, {a=>0, b=>2}), 1);
    is(cmp_data({a=>1}, {b=>1}), 2);
};

subtest scalarref => sub {
    my $s1 = \1;
    is(cmp_data($s1, $s1), 0);
    is(cmp_data($s1, \1), 2);
};

subtest "opt:cmp" => sub {
    is(cmp_data(undef, 1, {cmp=>sub {0}}), 0);
};

subtest "opt:elem_cmp" => sub {
    is(cmp_data([1,2,3],  [2,3,4] ,  {elem_cmp=>sub {length $_[0] <=> length $_[1]}}), 0);
    is(cmp_data([1,50,3], [1,10,3],  {elem_cmp=>sub {length $_[0] <=> length $_[1]}}), 0);
    is(cmp_data([1,50,3], [1,-10,3], {elem_cmp=>sub {length $_[0] <=> length $_[1]}}), -1);
};

subtest "opt:num_cmp" => sub {
    is(cmp_data([1,"a"], [1,"a"],
                {num_cmp=>sub {abs($_[0] - $_[1]) < 1 ? 0:2}}), 0);
    is(cmp_data([1,"a"], [1.5,"a"],
                {num_cmp=>sub {abs($_[0] - $_[1]) < 1 ? 0:2}}), 0);
    is(cmp_data([1,"a"], [1.5,"200b"],
                {str_cmp => sub {0},
                 num_cmp=>sub {abs($_[0] - $_[1]) < 1 ? 0:2}}), 0);
    is(cmp_data([1,"a"], [2,"a"],
                {num_cmp=>sub {abs($_[0] - $_[1]) < 1 ? 0:2}}), 2);
};

subtest "opt:str_cmp" => sub {
    is(cmp_data([1,"a"], [1,"a"],
                {str_cmp=>sub {length $_[0] <=> length $_[1]}}), 0);
    is(cmp_data([1,"a"], [1,"b"],
                {str_cmp=>sub {length $_[0] <=> length $_[1]}}), 0);
    is(cmp_data([1,"a"], [2,"b"],
                {num_cmp => sub {0},
                 str_cmp=>sub {length $_[0] <=> length $_[1]}}), 0);
    is(cmp_data([1,"ac"], [1,"b"],
                {str_cmp=>sub {length $_[0] <=> length $_[1]}}), 1);
};

# XXX cmparg:depth

DONE_TESTING:
done_testing;

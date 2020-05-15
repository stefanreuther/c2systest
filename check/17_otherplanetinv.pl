#!/usr/bin/perl -w
#
#  c2check: planet invariant errors on planets we don't own
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test planet invariants. Invariant elements must not change.
# Each of these tests tests:
# - modification of an invariant must give an error
# - invariant out of range must give an error
# - out-of-range invariant "-1" must be accepted with "-z"
test 'check/17_otherplanetinv/mines', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'mines', 'Mines', [2], [-2, 10001]);
};
test 'check/17_otherplanetinv/defense', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'defense', 'Defense', [2], [-2, 10001]);
};
test 'check/17_otherplanetinv/factories', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'factories', 'Factories', [2], [-2, 10001]);
};
test 'check/17_otherplanetinv/n', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'n', 'Mined N', [2], [-2]);
};
test 'check/17_otherplanetinv/t', sub {
    my $setup = shift;
    planet_invariant_test($setup, 't', 'Mined T', [2], [-2]);
};
test 'check/17_otherplanetinv/d', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'd', 'Mined D', [2], [-2]);
};
test 'check/17_otherplanetinv/m', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'm', 'Mined M', [2], [-2]);
};
test 'check/17_otherplanetinv/clans', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'clans', 'Colonists', [2], [-2]);
};
test 'check/17_otherplanetinv/sup', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'sup', 'Supplies', [2], [-2]);
};
test 'check/17_otherplanetinv/money', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'money', 'Money', [2], [-2]);
};
test 'check/17_otherplanetinv/ctax', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'ctax', 'Colonist Tax', [2], [-2]);
};
test 'check/17_otherplanetinv/ntax', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'ntax', 'Native Tax', [2], [-2]);
};

# Test buildbase flag. This one is special because it generates a range error on every change.
# A: prepare directory with "buildbase" set on a foreign planet
# E: check fails and produces a specific error message
test 'check/17_otherplanetinv/buildbase', sub {
    my $setup = shift;

    foreach my $v (-1, 1) {
        my $dir = ct_prepare_game_unpack($setup);
        make_foreign($dir);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{buildbase} = $v });
        ct_run_must_fail($setup, $dir, 'RANGE: Planet 10: Base Build Order out of allowed range');
    }
};

# Test base on unplayed planet.
test 'check/17_otherplanetinv/buildbase', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    make_foreign($dir);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{id} = 10 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{id} = 10 });
    ct_run_must_succeed_with_message($setup, $dir, "WARNING: Planet 10 has a starbase, although it is not played");
};

##
##  Canned test
##
sub planet_invariant_test {
    my ($setup, $field_name, $print_name, $changed_values, $invalid_values) = @_;

    foreach my $v (@$changed_values) {
        trace_process("Trying changed value $v");
        my $dir = ct_prepare_game_unpack($setup);
        make_foreign($dir);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, 'INVALID: Planet 10: '.$print_name.' was modified');
    }

    foreach my $v (@$invalid_values) {
        trace_process("Trying invalid value $v");
        my $dir = ct_prepare_game_unpack($setup);
        make_foreign($dir);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, 'RANGE: Planet 10: '.$print_name.' out of allowed range.');
    }

    # Negative values
    trace_process("Trying special value -1");
    my $dir = ct_prepare_game_unpack($setup);
    make_foreign($dir);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = -1 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{$field_name} = -1 });
    ct_run_must_fail($setup, $dir, 'RANGE: Planet 10: '.$print_name.' out of allowed range.');
    ct_run_must_succeed($setup, $dir, '-z');
}

# Helper
sub make_foreign {
    my $dir = shift;
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{owner} = 3 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{owner} = 3 });
}

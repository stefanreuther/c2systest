#!/usr/bin/perl -w
#
#  c2check: ship invariant errors
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test ship invariants. Invariant elements must not change.
# Each of these tests tests:
# - modification of an invariant must give an error
# - invariant out of range must give an error
# - out-of-range invariant "-1" must be accepted with "-z"
test 'check/15_shipinv/owner', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'owner', 'Owner', [2], [13, -2]);
};

test 'check/15_shipinv/x', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'x', 'X Position', [999], [-3, 20000]);
};

test 'check/15_shipinv/y', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'y', 'Y Position', [999], [-3, 20000]);
};

test 'check/15_shipinv/engine', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'engine', 'Engine type', [3, 4], [-3, 0, 10, 10000]);
};

test 'check/15_shipinv/hull', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'hull', 'Hull type', [3, 4], [-3, 0, 106, 10000]);
};

test 'check/15_shipinv/beamtype', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'beam', 'Beam type', [3, 4], [-3, 11]);
};

test 'check/15_shipinv/beamcount', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'nbeams', 'Beam count', [3, 4], [-3]);
};

test 'check/15_shipinv/baycount', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'nbays', 'Bay count', [3, 4], [-3]);
};

test 'check/15_shipinv/torptype', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'torp', 'Torp type', [3, 4], [-3, 11]);
};

test 'check/15_shipinv/tubecount', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'ntubes', 'Torp launcher count', [3, 4], [-3]);
};

test 'check/15_shipinv/damage', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'damage', 'Damage', [3, 4], [-3, 151]);
};

test 'check/15_shipinv/crew', sub {
    my $setup = shift;
    ship_invariant_test($setup, 'crew', 'Crew', [3, 4], [-3]);
};

# Test behaviour of crew with "picky" option.
# A: prepare game directory with out-of-range crew
# E: error result with '-p', success otherwise
test 'check/15_shipinv/crew_picky', sub {
    my $setup = shift;

    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{crew}++ });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{1}{crew}++ });
    ct_run_must_fail($setup, $dir, 'RANGE: Ship 7: Crew out of allowed range.', '-p');
    ct_run_must_succeed($setup, $dir);
};

##
##  Canned test
##
sub ship_invariant_test {
    my ($setup, $field_name, $print_name, $changed_values, $invalid_values) = @_;

    foreach my $v (@$changed_values) {
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, 'INVALID: Ship 7: '.$print_name.' was modified');
    }

    foreach my $v (@$invalid_values) {
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{$field_name} = $v });
        ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, 'RANGE: Ship 7: '.$print_name.' out of allowed range.');
    }

    # Negative values
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{owner} = -1 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{1}{owner} = -1 });
    ct_run_must_fail($setup, $dir, 'RANGE: Ship 7: Owner out of allowed range.');
    ct_run_must_succeed($setup, $dir, '-z');
}

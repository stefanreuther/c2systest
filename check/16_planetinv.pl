#!/usr/bin/perl -w
#
#  c2check: planet invariant errors
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
test 'check/16_planetinv/owner', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'owner', 'Owner', [2], [13, -2]);
};
test 'check/16_planetinv/gn', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'gn', 'Ground N', [10], [-2]);
};
test 'check/16_planetinv/gt', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'gt', 'Ground T', [10], [-2]);
};
test 'check/16_planetinv/gd', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'gd', 'Ground D', [10], [-2]);
};
test 'check/16_planetinv/gm', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'gm', 'Ground M', [10], [-2]);
};
test 'check/16_planetinv/dn', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'dn', 'Density N', [2], [-1, 101]);
};
test 'check/16_planetinv/dt', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'dt', 'Density T', [2], [-1, 101]);
};
test 'check/16_planetinv/dd', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'dd', 'Density D', [2], [-1, 101]);
};
test 'check/16_planetinv/dm', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'dm', 'Density M', [2], [-1, 101]);
};
test 'check/16_planetinv/chappy', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'chappy', 'Colonist Happiness', [2], [-301, 101], 1);
};
test 'check/16_planetinv/nhappy', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'nhappy', 'Native Happiness', [2], [-301, 101], 1);
};
test 'check/16_planetinv/ngov', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'ngov', 'Native Government', [2], [-3, 10]);
};
test 'check/16_planetinv/nclans', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'nclans', 'Natives', [2], [-3]);
};
test 'check/16_planetinv/nrace', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'nrace', 'Native Race', [2], [-3, 10]);
};
test 'check/16_planetinv/temp', sub {
    my $setup = shift;
    planet_invariant_test($setup, 'temp', 'Temperature', [2], [-2, 101]);
};


##
##  Canned test
##
sub planet_invariant_test {
    my ($setup, $field_name, $print_name, $changed_values, $invalid_values, $allow_m1) = @_;

    foreach my $v (@$changed_values) {
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, 'INVALID: Planet 10: '.$print_name.' was modified');
    }

    foreach my $v (@$invalid_values) {
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, 'RANGE: Planet 10: '.$print_name.' out of allowed range.');
    }

    # Negative values
    if (!$allow_m1) {
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = -1 });
        ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{$field_name} = -1 });
        ct_run_must_fail($setup, $dir, 'RANGE: Planet 10: '.$print_name.' out of allowed range.');
        ct_run_must_succeed($setup, $dir, '-z');
    }
}

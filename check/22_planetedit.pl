#!/usr/bin/perl -w
#
#  c2check: planet editable field checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test planet editable fields. Each of these tests tests:
# - modification out-of-range must give an error
# - if the value is out-of-range but not modified, it must give an error with "-p"
# Many of these will also give additional BALANCE errors.
# At this point, we're checking field ranges, not rules.
test 'check/22_planetedit/mines', sub {
    my $setup = shift;
    planet_editable_test($setup, 'mines', 'Mines', [-1,10001]);
};
test 'check/22_planetedit/factories', sub {
    my $setup = shift;
    planet_editable_test($setup, 'factories', 'Factories', [-1,10001]);
};
test 'check/22_planetedit/defense', sub {
    my $setup = shift;
    planet_editable_test($setup, 'defense', 'Defense', [-1,10001]);
};
test 'check/22_planetedit/n', sub {
    my $setup = shift;
    planet_editable_test($setup, 'n', 'Mined N', [-1]);
};
test 'check/22_planetedit/t', sub {
    my $setup = shift;
    planet_editable_test($setup, 't', 'Mined T', [-1]);
};
test 'check/22_planetedit/d', sub {
    my $setup = shift;
    planet_editable_test($setup, 'd', 'Mined D', [-1]);
};
test 'check/22_planetedit/m', sub {
    my $setup = shift;
    planet_editable_test($setup, 'm', 'Mined M', [-1]);
};
test 'check/22_planetedit/clans', sub {
    my $setup = shift;
    planet_editable_test($setup, 'clans', 'Colonists', [-1]);
};
test 'check/22_planetedit/sup', sub {
    my $setup = shift;
    planet_editable_test($setup, 'sup', 'Supplies', [-1]);
};
test 'check/22_planetedit/money', sub {
    my $setup = shift;
    planet_editable_test($setup, 'money', 'Money', [-1]);
};
test 'check/22_planetedit/ctax', sub {
    my $setup = shift;
    planet_editable_test($setup, 'ctax', 'Colonist Tax', [-1,101]);
};
test 'check/22_planetedit/ntax', sub {
    my $setup = shift;
    planet_editable_test($setup, 'ntax', 'Native Tax', [-1,101]);
};



##
##  Canned test
##
sub planet_editable_test {
    my ($setup, $field_name, $print_name, $values) = @_;

    # Test modification
    foreach my $v (@$values) {
        trace_process("Trying dat value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, "RANGE: Planet 10: $print_name out of allowed range.");
    }

    # Test previously-out-of-range
    foreach my $v (@$values) {
        trace_process("Trying dat+dis value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_succeed($setup, $dir);
        ct_run_must_fail($setup, $dir, "RANGE: Planet 10: $print_name out of allowed range.", '-p');
    }
}

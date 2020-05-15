#!/usr/bin/perl -w
#
#  c2check: base editable field checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test base editable fields. Each of these tests tests:
# - modification out-of-range must give an error
# - if the value is out-of-range but not modified, it must give an error with "-p"
# Many of these will also give additional BALANCE errors.
# At this point, we're checking field ranges, not rules.
test 'check/23_baseedit/basedefense', sub {
    my $setup = shift;
    base_editable_test($setup, 'basedefense', 'Base Defense', [-1,201]);
};
test 'check/23_baseedit/hulltech', sub {
    my $setup = shift;
    base_editable_test($setup, 'hulltech', 'Hull Tech', [-1,0,11,1000]);
};
test 'check/23_baseedit/enginetech', sub {
    my $setup = shift;
    base_editable_test($setup, 'enginetech', 'Engine Tech', [-1,0,11,1000]);
};
test 'check/23_baseedit/beamtech', sub {
    my $setup = shift;
    base_editable_test($setup, 'beamtech', 'Beam Tech', [-1,0,11,1000]);
};
test 'check/23_baseedit/torptech', sub {
    my $setup = shift;
    base_editable_test($setup, 'torptech', 'Torp Tech', [-1,0,11,1000]);
};
test 'check/23_baseedit/shipaction', sub {
    my $setup = shift;
    base_editable_test($setup, 'shipaction', 'Shipyard Action', [-1,3]);
};
test 'check/23_baseedit/shipid', sub {
    my $setup = shift;
    base_editable_test($setup, 'shipid', 'Shipyard Ship', [-1,1000]);
};
test 'check/23_baseedit/mission', sub {
    my $setup = shift;
    base_editable_test($setup, 'mission', 'Base Mission', [-1,7]);
};

# Storage: we allow any nonnegative value
test 'check/23_baseedit/e1', sub {
    my $setup = shift;
    base_editable_test($setup, 'e1', 'Engine storage #1', [-1]);
};
test 'check/23_baseedit/e9', sub {
    my $setup = shift;
    base_editable_test($setup, 'e9', 'Engine storage #9', [-1]);
};
test 'check/23_baseedit/b1', sub {
    my $setup = shift;
    base_editable_test($setup, 'b1', 'Beam storage #1', [-1]);
};
test 'check/23_baseedit/b10', sub {
    my $setup = shift;
    base_editable_test($setup, 'b10', 'Beam storage #10', [-1]);
};
test 'check/23_baseedit/l1', sub {
    my $setup = shift;
    base_editable_test($setup, 'l1', 'Launcher storage #1', [-1]);
};
test 'check/23_baseedit/l10', sub {
    my $setup = shift;
    base_editable_test($setup, 'l10', 'Launcher storage #10', [-1]);
};
test 'check/23_baseedit/t1', sub {
    my $setup = shift;
    base_editable_test($setup, 't1', 'Torpedo storage #1', [-1]);
};
test 'check/23_baseedit/t10', sub {
    my $setup = shift;
    base_editable_test($setup, 't10', 'Torpedo storage #10', [-1]);
};
test 'check/23_baseedit/h1', sub {
    my $setup = shift;
    base_editable_test($setup, 'h1', 'Hull storage #1', [-1]);
};
test 'check/23_baseedit/h20', sub {
    my $setup = shift;
    base_editable_test($setup, 'h20', 'Unused hull storage #20', [-1]);
};
test 'check/23_baseedit/buildslot', sub {
    my $setup = shift;
    base_editable_test($setup, 'buildslot', 'Build order: Hull', [-1,21,10000]);
};
test 'check/23_baseedit/buildengine', sub {
    my $setup = shift;
    base_editable_test($setup, 'buildengine', 'Build order: Engine', [-1,10]);
};
test 'check/23_baseedit/buildbeam', sub {
    my $setup = shift;
    base_editable_test($setup, 'buildbeam', 'Build order: Beam type', [-1,11]);
};
test 'check/23_baseedit/buildtorp', sub {
    my $setup = shift;
    base_editable_test($setup, 'buildtorp', 'Build order: Torp type', [-1,11]);
};



##
##  Canned test
##
sub base_editable_test {
    my ($setup, $field_name, $print_name, $values) = @_;

    # Test modification
    foreach my $v (@$values) {
        trace_process("Trying dat value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, "RANGE: Starbase 63: $print_name out of allowed range.");
    }

    # Test previously-out-of-range
    foreach my $v (@$values) {
        trace_process("Trying dat+dis value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{$field_name} = $v });
        ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_succeed($setup, $dir);
        ct_run_must_fail($setup, $dir, "RANGE: Starbase 63: $print_name out of allowed range.", '-p');
    }
}

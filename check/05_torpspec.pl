#!/usr/bin/perl -w
#
#  c2check: torpspec checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $desc = {
    fields => [qw'name torpcost money t d m mass tech kill damage'],
    pattern => 'A20v9',
    mode => 'auto'
};

# Test missing torpspec.
# A: remove file
# E: error result
test 'check/05_torpspec/missing', sub {
    my $setup = shift;
    ct_test_missing_file($setup, 'torpspec.dat');
};

# Test truncated torpspec.
# A: truncate file
# E: error result
test 'check/05_torpspec/trunc', sub {
    my $setup = shift;
    ct_test_truncated_file($setup, 'torpspec.dat', 300);
};

# Test mc out of range.
# A: prepare out-of-range values
# E: error result for most; success result for -1/"-z" case
# (applies to all following tests)
test 'check/05_torpspec/mc', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 2: MC cost out of allowed range',  sub { shift->{2}{money} = -1; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 10: MC cost out of allowed range', sub { shift->{10}{money} = -9; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 1: MC cost out of allowed range',  sub { shift->{1}{money} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'torpspec.dat', $desc, sub { shift->{2}{money} = -1; });
};

# Test Tri out of range.
test 'check/05_torpspec/tri', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 2: Tri cost out of allowed range',  sub { shift->{2}{t} = -1; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 10: Tri cost out of allowed range', sub { shift->{10}{t} = -9; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 1: Tri cost out of allowed range',  sub { shift->{1}{t} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'torpspec.dat', $desc, sub { shift->{2}{t} = -1; });
};

# Test Dur out of range.
test 'check/05_torpspec/dur', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 2: Dur cost out of allowed range',  sub { shift->{2}{d} = -1; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 10: Dur cost out of allowed range', sub { shift->{10}{d} = -9; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 1: Dur cost out of allowed range',  sub { shift->{1}{d} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'torpspec.dat', $desc, sub { shift->{2}{d} = -1; });
};

# Test Mol out of range.
test 'check/05_torpspec/mol', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 2: Mol cost out of allowed range',  sub { shift->{2}{m} = -1; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 10: Mol cost out of allowed range', sub { shift->{10}{m} = -9; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 1: Mol cost out of allowed range',  sub { shift->{1}{m} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'torpspec.dat', $desc, sub { shift->{2}{m} = -1; });
};

# Test tech out of range.
test 'check/05_torpspec/tech', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 2: Tech level out of allowed range',  sub { shift->{2}{tech} = -1; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 10: Tech level out of allowed range', sub { shift->{10}{tech} = 11; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 1: Tech level out of allowed range',  sub { shift->{1}{tech} = 0; });
    ct_test_edited_spec_file_m1($setup, 'torpspec.dat', $desc, sub { shift->{2}{tech} = -1; });
};

# Test torpedo cost out of range.
test 'check/05_torpspec/torpcost', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 2: Torp MC cost out of allowed range',  sub { shift->{2}{torpcost} = -9; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 10: Torp MC cost out of allowed range', sub { shift->{10}{torpcost} = -1; });
    ct_test_edited_spec_file($setup, 'torpspec.dat', $desc, 'RANGE: Torpedo 1: Torp MC cost out of allowed range',  sub { shift->{1}{torpcost} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'torpspec.dat', $desc, sub { shift->{10}{torpcost} = -1; });
};

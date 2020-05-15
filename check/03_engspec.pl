#!/usr/bin/perl -w
#
#  c2check: engspec checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $desc = {
    fields => [qw'name money t d m tech w1 w2 w3 w4 w5 w6 w7 w8 w9'],
    pattern => 'A20v5V9',
    mode => 'auto'
};

# Test missing engspec.
# A: remove file
# E: error result
test 'check/03_engspec/missing', sub {
    my $setup = shift;
    ct_test_missing_file($setup, 'engspec.dat');
};

# Test truncated engspec.
# A: truncate file
# E: error result
test 'check/03_engspec/trunc', sub {
    my $setup = shift;
    ct_test_truncated_file($setup, 'engspec.dat', 400);
};

# Test mc out of range.
# A: prepare out-of-range values
# E: error result for most; success result for -1/"-z" case
# (applies to all following tests)
test 'check/03_engspec/mc', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 2: MC cost out of allowed range', sub { shift->{2}{money} = -1; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 9: MC cost out of allowed range', sub { shift->{9}{money} = -9; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 1: MC cost out of allowed range', sub { shift->{1}{money} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'engspec.dat', $desc, sub { shift->{2}{money} = -1; });
};

# Test Tri out of range.
test 'check/03_engspec/tri', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 2: Tri cost out of allowed range', sub { shift->{2}{t} = -1; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 9: Tri cost out of allowed range', sub { shift->{9}{t} = -9; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 1: Tri cost out of allowed range', sub { shift->{1}{t} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'engspec.dat', $desc, sub { shift->{2}{t} = -1; });
};

# Test Dur out of range.
test 'check/03_engspec/dur', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 2: Dur cost out of allowed range', sub { shift->{2}{d} = -1; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 9: Dur cost out of allowed range', sub { shift->{9}{d} = -9; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 1: Dur cost out of allowed range', sub { shift->{1}{d} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'engspec.dat', $desc, sub { shift->{2}{d} = -1; });
};

# Test Mol out of range.
test 'check/03_engspec/mol', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 2: Mol cost out of allowed range', sub { shift->{2}{m} = -1; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 9: Mol cost out of allowed range', sub { shift->{9}{m} = -9; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 1: Mol cost out of allowed range', sub { shift->{1}{m} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'engspec.dat', $desc, sub { shift->{2}{m} = -1; });
};

# Test tech out of range.
test 'check/03_engspec/tech', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 2: Tech level out of allowed range', sub { shift->{2}{tech} = -1; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 9: Tech level out of allowed range', sub { shift->{9}{tech} = 0; });
    ct_test_edited_spec_file($setup, 'engspec.dat', $desc, 'RANGE: Engine 1: Tech level out of allowed range', sub { shift->{1}{tech} = 11; });
    ct_test_edited_spec_file_m1($setup, 'engspec.dat', $desc, sub { shift->{2}{tech} = -1; });
};

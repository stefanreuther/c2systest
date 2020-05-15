#!/usr/bin/perl -w
#
#  c2check: beamspec checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $desc = {
    fields => [qw'name money t d m mass tech kill damage'],
    pattern => 'A20v8',
    mode => 'auto'
};

# Test missing beamspec.
# A: remove file
# E: error result
test 'check/04_beamspec/missing', sub {
    my $setup = shift;
    ct_test_missing_file($setup, 'beamspec.dat');
};

# Test truncated beamspec.
# A: truncate file
# E: error result
test 'check/04_beamspec/trunc', sub {
    my $setup = shift;
    ct_test_truncated_file($setup, 'beamspec.dat', 300);
};

# Test mc out of range.
# A: prepare out-of-range values
# E: error result for most; success result for -1/"-z" case
# (applies to all following tests)
test 'check/04_beamspec/mc', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 2: MC cost out of allowed range',  sub { shift->{2}{money} = -1; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 10: MC cost out of allowed range', sub { shift->{10}{money} = -9; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 1: MC cost out of allowed range',  sub { shift->{1}{money} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'beamspec.dat', $desc, sub { shift->{2}{money} = -1; });
};

# Test Tri out of range.
test 'check/04_beamspec/tri', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 2: Tri cost out of allowed range',  sub { shift->{2}{t} = -1; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 10: Tri cost out of allowed range', sub { shift->{10}{t} = -9; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 1: Tri cost out of allowed range',  sub { shift->{1}{t} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'beamspec.dat', $desc, sub { shift->{2}{t} = -1; });
};

# Test Dur out of range.
test 'check/04_beamspec/dur', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 2: Dur cost out of allowed range',  sub { shift->{2}{d} = -1; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 10: Dur cost out of allowed range', sub { shift->{10}{d} = -9; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 1: Dur cost out of allowed range',  sub { shift->{1}{d} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'beamspec.dat', $desc, sub { shift->{2}{d} = -1; });
};

# Test Mol out of range.
test 'check/04_beamspec/mol', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 2: Mol cost out of allowed range',  sub { shift->{2}{m} = -1; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 10: Mol cost out of allowed range', sub { shift->{10}{m} = -9; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 1: Mol cost out of allowed range',  sub { shift->{1}{m} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'beamspec.dat', $desc, sub { shift->{2}{m} = -1; });
};

# Test tech out of range.
test 'check/04_beamspec/tech', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 2: Tech level out of allowed range',  sub { shift->{2}{tech} = -1; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 10: Tech level out of allowed range', sub { shift->{10}{tech} = 11; });
    ct_test_edited_spec_file($setup, 'beamspec.dat', $desc, 'RANGE: Beam 1: Tech level out of allowed range',  sub { shift->{1}{tech} = 0; });
    ct_test_edited_spec_file_m1($setup, 'beamspec.dat', $desc, sub { shift->{2}{tech} = -1; });
};

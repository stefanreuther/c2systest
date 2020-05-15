#!/usr/bin/perl -w
#
#  c2check: hullspec checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $desc = {
    fields => [qw'name pic one t d m fuel crew nengines mass tech cargo nbays ntubes nbeams money'],
    pattern => 'A30v15',
    mode => 'auto'
};

# Test missing hullspec file.
# A: remove file
# E: error result
test 'check/02_hullspec/missing', sub {
    my $setup = shift;
    ct_test_missing_file($setup, 'hullspec.dat');
};

# Test truncated hullspec file.
# A: truncate file
# E: error result
test 'check/02_hullspec/trunc', sub {
    my $setup = shift;
    ct_test_truncated_file($setup, 'hullspec.dat', 3000);
};

# Test mc out of range.
# A: prepare out-of-range values
# E: error result for most; success result for -1/"-z" case
# (applies to all following tests)
test 'check/02_hullspec/mc', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: MC cost out of allowed range',   sub { shift->{2}{money} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: MC cost out of allowed range', sub { shift->{105}{money} = -9; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: MC cost out of allowed range',   sub { shift->{1}{money} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{money} = -1; });
};

# Test Tri out of range.
test 'check/02_hullspec/tri', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Tri cost out of allowed range',   sub { shift->{2}{t} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Tri cost out of allowed range', sub { shift->{105}{t} = -9; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Tri cost out of allowed range',   sub { shift->{1}{t} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{t} = -1; });
};

# Test Dur out of range.
test 'check/02_hullspec/dur', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Dur cost out of allowed range',   sub { shift->{2}{d} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Dur cost out of allowed range', sub { shift->{105}{d} = -9; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Dur cost out of allowed range',   sub { shift->{1}{d} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{d} = -1; });
};

# Test Mol out of range.
test 'check/02_hullspec/mol', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Mol cost out of allowed range',   sub { shift->{2}{m} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Mol cost out of allowed range', sub { shift->{105}{m} = -9; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Mol cost out of allowed range',   sub { shift->{1}{m} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{m} = -1; });
};

# Test tech out of range.
test 'check/02_hullspec/tech', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Tech level out of allowed range',   sub { shift->{2}{tech} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Tech level out of allowed range', sub { shift->{105}{tech} = 11; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Tech level out of allowed range',   sub { shift->{1}{tech} = 0; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{tech} = -1; });
};

# Test fuel out of range
test 'check/02_hullspec/fuel', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Fuel tank out of allowed range',   sub { shift->{2}{fuel} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Fuel tank out of allowed range', sub { shift->{105}{fuel} = -1000; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Fuel tank out of allowed range',   sub { shift->{1}{fuel} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{fuel} = -1; });
};

# Test engines of range
test 'check/02_hullspec/engines', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Engines out of allowed range',   sub { shift->{2}{nengines} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Engines out of allowed range', sub { shift->{105}{nengines} = 0; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Engines out of allowed range',   sub { shift->{1}{nengines} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{nengines} = -1; });
};

# Test cargo out of range
test 'check/02_hullspec/cargo', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Cargo room out of allowed range',   sub { shift->{2}{cargo} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Cargo room out of allowed range', sub { shift->{105}{cargo} = -1000; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Cargo room out of allowed range',   sub { shift->{1}{cargo} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{cargo} = -1; });
};

# Test bays out of range
test 'check/02_hullspec/bays', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Fighter bay count out of allowed range',   sub { shift->{2}{nbays} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Fighter bay count out of allowed range', sub { shift->{105}{nbays} = -1000; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Fighter bay count out of allowed range',   sub { shift->{1}{nbays} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{nbays} = -1; });
};

# Test launchers out of range
test 'check/02_hullspec/launchers', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Torp launcher count out of allowed range',   sub { shift->{2}{ntubes} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Torp launcher count out of allowed range', sub { shift->{105}{ntubes} = -1000; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Torp launcher count out of allowed range',   sub { shift->{1}{ntubes} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{ntubes} = -1; });
};

# Test beams out of range
test 'check/02_hullspec/fuel', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 2: Beam count out of allowed range',   sub { shift->{2}{nbeams} = -1; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 105: Beam count out of allowed range', sub { shift->{105}{nbeams} = -1000; });
    ct_test_edited_spec_file($setup, 'hullspec.dat', $desc, 'RANGE: Hull 1: Beam count out of allowed range',   sub { shift->{1}{nbeams} = -32768; });
    ct_test_edited_spec_file_m1($setup, 'hullspec.dat', $desc, sub { shift->{2}{nbeams} = -1; });
};

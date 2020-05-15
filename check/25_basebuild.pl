#!/usr/bin/perl -w
#
#  c2check: ship build orders on base
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test the "zero" word.
# A: set the 'buildzero' word
# E: Check must succeed. This is currently NOT an error.
test 'check/25_basebuild/zero', sub {
    my $setup = shift;
    foreach my $v (-1, 1, 1000) {
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{buildzero} = $v });
        ct_run_must_succeed_with_message($setup, $dir, "WARNING: The last word of starbase 63's ship build order is not zero.");
    }
};

# Test building using a nonexistant hull
# A: build a non-existant slot
# E: Check must fail
test 'check/25_basebuild/nxhull', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h20} = 1;
                     $e->{1}{e9} = 1;
                     $e->{1}{buildslot} = 20;
                     $e->{1}{buildengine} = 9;
                 });
    ct_run_must_fail($setup, $dir, "Build order refers to a non-existant hull type.");
};

# Test building using a nonexistant owner
# A: build using a non-existant base owner
# E: Check must fail
test 'check/25_basebuild/nxowner', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{baseowner} = 1000;
                     $e->{1}{h1} = 1;
                     $e->{1}{e9} = 1;
                     $e->{1}{buildslot} = 1;
                     $e->{1}{buildengine} = 9;
                 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{baseowner} = 1000 });
    ct_run_must_fail($setup, $dir, "Build order refers to a non-existant hull type.");
};

# Test building without a hull
# A: build a ship using a hull that is not in storage
# E: Check must fail
test 'check/25_basebuild/nohull', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h1} = 0;
                     $e->{1}{e9} = 1;
                     $e->{1}{buildslot} = 1;
                     $e->{1}{buildengine} = 9;
                 });
    ct_run_must_fail($setup, $dir, "that hull is not available in storage.");
};

# Test building without an engine
# A: build a ship using an engine that is not in storage
# E: Check must fail
test 'check/25_basebuild/noengine', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h1} = 1;
                     $e->{1}{buildslot} = 1;
                     $e->{1}{buildengine} = 0;
                 });
    ct_run_must_fail($setup, $dir, "Attempt to build ship without engine.");
};

# Test "not in storage" cases
# A: build a ship using components of which we have too few in storage
#    Slot 5: RUBY CLASS LIGHT CARRIER, 2 engines, 4 beams, 2 tubes
# E: Check must fail
test 'check/25_basebuild/missing/engine', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h5} = 1;
                     $e->{1}{buildslot} = 5;
                     $e->{1}{e3} = 1;
                     $e->{1}{buildengine} = 3;
                 });
    ct_run_must_fail($setup, $dir, "Attempt to build ship with 2 engines");
    ct_run_must_fail($setup, $dir, "Available in storage are 1");
};
test 'check/25_basebuild/missing/beam', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h5} = 1;
                     $e->{1}{buildslot} = 5;
                     $e->{1}{e3} = 2;
                     $e->{1}{buildengine} = 3;
                     $e->{1}{b7} = 3;
                     $e->{1}{buildbeam} = 7;
                     $e->{1}{buildnbeam} = 4;
                 });
    ct_run_must_fail($setup, $dir, "Attempt to build ship with 4 beams");
    ct_run_must_fail($setup, $dir, "Available in storage are 3");
};
test 'check/25_basebuild/missing/tube', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h5} = 1;
                     $e->{1}{buildslot} = 5;
                     $e->{1}{e3} = 2;
                     $e->{1}{buildengine} = 3;
                     $e->{1}{b7} = 3;
                     $e->{1}{buildbeam} = 7;
                     $e->{1}{buildnbeam} = 4;
                     $e->{1}{l6} = 1;
                     $e->{1}{buildtorp} = 6;
                     $e->{1}{buildntube} = 2;
                 });
    ct_run_must_fail($setup, $dir, "Attempt to build ship with 2 torpedo launchers");
    ct_run_must_fail($setup, $dir, "Available in storage are 1");
};

# Test "too many for hull" cases
# A: build a ship, ordering more components than the hull allows
#    Slot 5: RUBY CLASS LIGHT CARRIER, 2 engines, 4 beams, 2 tubes
# E: Check must fail
test 'check/25_basebuild/many/beam', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h5} = 1;
                     $e->{1}{buildslot} = 5;
                     $e->{1}{e3} = 2;
                     $e->{1}{buildengine} = 3;
                     $e->{1}{b7} = 30;
                     $e->{1}{buildbeam} = 7;
                     $e->{1}{buildnbeam} = 10;
                 });
    ct_run_must_fail($setup, $dir, "Attempt to build ship with 10 beams");
    ct_run_must_fail($setup, $dir, "Maximum allowed by hull is 4");
};
test 'check/25_basebuild/many/tube', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{h5} = 1;
                     $e->{1}{buildslot} = 5;
                     $e->{1}{e3} = 2;
                     $e->{1}{buildengine} = 3;
                     $e->{1}{b7} = 4;
                     $e->{1}{buildbeam} = 7;
                     $e->{1}{buildnbeam} = 4;
                     $e->{1}{l6} = 100;
                     $e->{1}{buildtorp} = 6;
                     $e->{1}{buildntube} = 20;
                 });
    ct_run_must_fail($setup, $dir, "Attempt to build ship with 20 torpedo launchers");
    ct_run_must_fail($setup, $dir, "Maximum allowed by hull is 2");
};

#!/usr/bin/perl -w
#
#  c2check: test RST errors
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $rst_header_spec = {
    mode => 'fixed',
    count => 8,
    pattern => 'V',
    fields => ['adr']
};

my $RST_SIZE = 30377;
test_failure 'data/game2/player7.rst does not match test'
    if length(file_content("data/game2/player7.rst")) != $RST_SIZE;

# Test missing RST file.
# A: Prepare directory without RST file.
# E: Check must fail, error must reference missing RST file.
test 'check/09_rst/missing', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    unlink "$dir/player7.rst";
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test truncated RST file.
# A: Prepare empty RST file (unreadable header).
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc1', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.rst", "");
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test truncated RST file.
# A: Prepare truncated RST file (unreadable header).
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.rst", substr(file_content("$dir/player7.rst"), 0, 30));
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test RST file with bad pointer.
# A: Prepare RST file with too low address.
# E: Check must fail with specific error.
test 'check/09_rst/pointer', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub { shift->{3}{adr} = 3 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: Section 3 pointer points outside file', '-r');
};

# Test RST file with bad pointer.
# A: Prepare RST file with too high address.
# E: Check must fail with specific error.
test 'check/09_rst/pointer2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub { shift->{7}{adr} = 99999 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: Section 7 pointer points outside file', '-r');
};

# Test RST file with bad counter.
# A: Prepare RST file with ship count -1.
# E: Check must fail with specific error.
test 'check/09_rst/counter', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{1}{adr}-33, 2) = pack("v", -1);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: Section 1 counter out of range', '-r');
};

# Test RST file with bad counter.
# A: Prepare RST file with ship count 1000. Pad to make sure 1000 ships would actually fit.
# E: Check must fail with specific error.
test 'check/09_rst/counter2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{1}{adr}-33, 2) = pack("v", 1000);
                     $e->{rest} .= 'x' x 107000;
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: Section 1 counter out of range', '-r');
};

# Test RST file with truncated section.
# A: Prepare RST file with ship count 900. Don't pad so this fails a size check.
# E: Check must fail with specific error.
test 'check/09_rst/trunc/sec1', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{1}{adr}-33, 2) = pack("v", 900);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: Section 1 truncated', '-r');
};

# Test RST file with truncated section.
# A: Prepare RST with VCR count 900.
# E: Check must fail with specific error.
test 'check/09_rst/trunc/sec8', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{8}{adr}-33, 2) = pack("v", 900);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: Section 8 truncated', '-r');
};

# Test RST file with truncated GEN section.
# A: Prepare RST where pointer points short before end.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc/time', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub { shift->{7}{adr} = $RST_SIZE; });
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test RST file with truncated GEN section.
# A: Prepare RST where pointer points short before end.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/badtime', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{7}{adr}-33, 5) = '99x99';
                 });
    ct_run_must_fail($setup, $dir, 'Time stamp has an invalid format', '-r');
};

# Test RST file with bad ship Id.
# A: Prepare RST with ship Id 0.
# E: Check must fail with specific error.
test 'check/09_rst/ship/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{1}{adr}-31, 2) = pack("v", 0);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains invalid ship Id 0', '-r');
};

# Test RST file with bad ship Id.
# A: Prepare RST with ship Id 1000.
# E: Check must fail with specific error.
test 'check/09_rst/ship/bad2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{1}{adr}-31, 2) = pack("v", 1000);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains invalid ship Id 1000', '-r');
};

# Test RST file with duplicate ship Id.
# A: Prepare RST with duplicate ship Id.
# E: Check must fail with specific error.
test 'check/09_rst/ship/dup', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     # RST contains ships 7, 18, ...
                     my $e = shift;
                     substr($e->{rest}, $e->{1}{adr}-31, 2) = pack("v", 18);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains duplicate ship Id 18', '-r');
};

# Test RST file with bad planet Id.
# A: Prepare RST with planet Id 0.
# E: Check must fail with specific error.
test 'check/09_rst/planet/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{3}{adr}-31+2, 2) = pack("v", 0);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains invalid planet Id 0', '-r');
};

# Test RST file with bad planet Id.
# A: Prepare RST with planet Id 501.
# E: Check must fail with specific error.
test 'check/09_rst/planet/bad2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{3}{adr}-31+2, 2) = pack("v", 501);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains invalid planet Id 501', '-r');
};

# Test RST file with duplicate planet Id.
# A: Prepare RST with duplicate planet Id.
# E: Check must fail with specific error.
test 'check/09_rst/planet/dup', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     # RST contains planets 10, 14, ...
                     my $e = shift;
                     substr($e->{rest}, $e->{3}{adr}-31+2, 2) = pack("v", 14);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains duplicate planet Id 14', '-r');
};

# Test RST file with bad base Id.
# A: Prepare RST with base Id 0.
# E: Check must fail with specific error.
test 'check/09_rst/base/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{4}{adr}-31, 2) = pack("v", 0);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains invalid planet Id 0', '-r');
};

# Test RST file with bad base Id.
# A: Prepare RST with base Id 501.
# E: Check must fail with specific error.
test 'check/09_rst/base/bad2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     my $e = shift;
                     substr($e->{rest}, $e->{4}{adr}-31, 2) = pack("v", 501);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains invalid planet Id 501', '-r');
};

# Test RST file with duplicate base Id.
# A: Prepare RST with duplicate base Id.
# E: Check must fail with specific error.
test 'check/09_rst/base/dup', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     # RST contains bases 63, 140, ...
                     my $e = shift;
                     substr($e->{rest}, $e->{4}{adr}-31, 2) = pack("v", 140);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains duplicate planet Id 140', '-r');
};

# Test RST file with bad base Id.
# A: Prepare RST with base at unowned planet.
# E: Check must fail with specific error.
test 'check/09_rst/base/foreign', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub 
                 {
                     # RST contains bases 63, 140, ...
                     my $e = shift;
                     substr($e->{rest}, $e->{4}{adr}-31, 2) = pack("v", 1);
                 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.rst contains base at foreign planet 1', '-r');
};



##
##  Obscure test cases
##
##  These test cases happen to work this way only because of the specific implementation
##  which does not currently (20180204) catch them in the "section X truncated" case due to being off-by-one.
##

# Test RST file with truncated SHIP section.
# A: Prepare RST where pointer points short before end.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc/nships', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub { shift->{1}{adr} = $RST_SIZE; });
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test RST file with truncated SHIP section.
# A: Prepare RST where pointer points at a ship which is just too short.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc/ship', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub
                 { 
                     my $e = shift;
                     my $ship = substr($e->{rest}, $e->{1}{adr}-31, 106); # note 106, not 107
                     $e->{1}{adr} = $RST_SIZE+1;
                     $e->{rest} .= pack("v", 1) . $ship;
                 });
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test RST file with truncated PDATA section.
# A: Prepare RST where pointer points short before end.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc/nplanets', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub { shift->{3}{adr} = $RST_SIZE; });
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test RST file with truncated PDATA section.
# A: Prepare RST where pointer points at a planet which is just too short.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc/planet', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub
                 { 
                     my $e = shift;
                     my $pl = substr($e->{rest}, $e->{3}{adr}-31, 84); # note 84, not 85
                     $e->{3}{adr} = $RST_SIZE+1;
                     $e->{rest} .= pack("v", 1) . $pl;
                 });
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test RST file with truncated BDATA section.
# A: Prepare RST where pointer points short before end.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc/nbases', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub { shift->{4}{adr} = $RST_SIZE; });
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

# Test RST file with truncated BDATA section.
# A: Prepare RST where pointer points at a base which is just too short.
# E: Check must fail, error must reference truncated RST file.
test 'check/09_rst/trunc/planet', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    ct_edit_file("$dir/player7.rst", $rst_header_spec, sub
                 { 
                     my $e = shift;
                     my $b = substr($e->{rest}, $e->{4}{adr}-31, 155); # note 155, not 156
                     $e->{4}{adr} = $RST_SIZE+1;
                     $e->{rest} .= pack("v", 1) . $b;
                 });
    ct_run_must_fail($setup, $dir, 'player7.rst', '-r');
};

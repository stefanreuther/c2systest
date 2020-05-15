#!/usr/bin/perl -w
#
#  un-trn: basic functionality test
#
use strict;
use c2systest;

test 'untrn/01_list', sub {
    my $setup = shift;
    my $prog = setup_get_required_system_config($setup, 'c2untrn.path');
    my $in   = cmdl_input_file('player7.trn');
    my $ref  = cmdl_input_file('player7.lst');
    my $out  = setup_get_tmpfile_name($setup, 'player7.lst');

    assert_execution_succeeds "$prog $in > $out";
    assert_execution_succeeds "diff --ignore-matching-lines='^; Listing of' $ref $out";
};

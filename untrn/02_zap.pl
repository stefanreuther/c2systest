#!/usr/bin/perl -w
#
#  un-trn: test of "-z" option
#
use strict;
use c2systest;

test 'untrn/02_zap', sub {
    my $setup = shift;
    my $prog = setup_get_required_system_config($setup, 'c2untrn.path');
    my $in   = cmdl_input_file('player7.trn');
    my $ref  = cmdl_input_file('empty.trn');
    my $out  = setup_get_tmpfile_name($setup, 'work.trn');

    assert_execution_succeeds "cp $in $out";
    assert_execution_succeeds "$prog -rz $out";
    assert_binary_file_identical($ref, $out,
                                 [0, 28],            # File header
                                 [28, 320],          # 3.5 trailer excluding signature
                                 [352, 248]);        # 3.0 trailer
};

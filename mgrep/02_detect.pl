#!/usr/bin/perl -w
#
#  mgrep: addressee parsing
#
use strict;
use c2systest;

# Test sending a message to host in 3.0 format.
# c2mgrep-ng misdetected this file as an inbox file.
test 'mgrep/02_detect', sub {
    my $setup = shift;
    my $file_name = setup_get_tmpfile_name($setup, 'test.dat');
    file_put($file_name, 
             join('', map{chr}
                  1,0,                       # count
                  13,0,0,0,                  # address
                  6,0,                       # length
                  7,0,                       # from
                  12,0,                      # to
                  110,111,112,26,113,114));  # abc\nde

    my $shell = shell_new($setup, 'mgrep');
    shell_add_args($shell, 'a', $file_name);
    assert_contains shell_call($shell), 'TO: host';
};

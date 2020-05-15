#!/usr/bin/perl -w
#
#  mgrep: addressee parsing
#
use strict;
use c2systest;

# Test sending a message to host in 3.0 format.
test 'mgrep/90_365_to/30host', sub {
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
    shell_add_args($shell, '-d', 'a', $file_name);
    assert_contains shell_call($shell), 'TO: host';
};

# Test sending a message to host in 3.5 format.
test 'mgrep/90_365_to/35host', sub {
    my $setup = shift;
    my $file_name = setup_get_tmpfile_name($setup, 'test.dat');
    file_put($file_name, 
             join('', map{chr}
                  1,0,                                  # count,
                  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,    # pad
                  3,                                    # pad
                  49,                                   # valid
                  48,48,48,48,48,48,48,48,48,48,48,49,  # receivers
                  10,0,                                 # length
                  110,111,112,26,113,114,45,45,45,45)); # abc\nde
    my $shell = shell_new($setup, 'mgrep');
    shell_add_args($shell, '-w', 'a', $file_name);
    assert_contains shell_call($shell), 'TO: host';
};

# Test sending a universal message in 3.5 format.
test 'mgrep/90_365_to/35univ', sub {
    my $setup = shift;
    my $file_name = setup_get_tmpfile_name($setup, 'test.dat');
    file_put($file_name, 
             join('', map{chr}
                  1,0,                                  # count,
                  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,    # pad
                  3,                                    # pad
                  49,                                   # valid
                  49,49,49,49,49,49,49,49,49,49,49,48,  # receivers
                  10,0,                                 # length
                  110,111,112,26,113,114,45,45,45,45)); # abc\nde
    my $shell = shell_new($setup, 'mgrep');
    shell_add_args($shell, '-w', 'a', $file_name);
    assert_contains shell_call($shell), 'TO: all players';
};

# Test sending a message to all players and host in 3.5 format.
test 'mgrep/90_365_to/35univ+host', sub {
    my $setup = shift;
    my $file_name = setup_get_tmpfile_name($setup, 'test.dat');
    file_put($file_name, 
             join('', map{chr}
                  1,0,                                  # count,
                  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,    # pad
                  3,                                    # pad
                  49,                                   # valid
                  49,49,49,49,49,49,49,49,49,49,49,49,  # receivers
                  10,0,                                 # length
                  110,111,112,26,113,114,45,45,45,45)); # abc\nde
    my $shell = shell_new($setup, 'mgrep');
    shell_add_args($shell, '-w', 'a', $file_name);
    assert_contains shell_call($shell), 'TO: host, all players';
};

# Test sending a message to player 3 and host in 3.5 format.
test 'mgrep/90_365_to/35player+host', sub {
    my $setup = shift;
    my $file_name = setup_get_tmpfile_name($setup, 'test.dat');
    file_put($file_name, 
             join('', map{chr}
                  1,0,                                  # count,
                  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,    # pad
                  3,                                    # pad
                  49,                                   # valid
                  48,48,49,48,48,48,48,48,48,48,48,49,  # receivers
                  10,0,                                 # length
                  110,111,112,26,113,114,45,45,45,45)); # abc\nde
    my $shell = shell_new($setup, 'mgrep');
    shell_add_args($shell, '-w', 'a', $file_name);
    assert_contains shell_call($shell), 'TO: host, player 3';
};

# Test sending a message to all but player 3, plus host in 3.5 format.
test 'mgrep/90_365_to/35notplayer+host', sub {
    my $setup = shift;
    my $file_name = setup_get_tmpfile_name($setup, 'test.dat');
    file_put($file_name, 
             join('', map{chr}
                  1,0,                                  # count,
                  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,    # pad
                  3,                                    # pad
                  49,                                   # valid
                  49,49,48,49,49,49,49,49,49,49,49,49,  # receivers
                  10,0,                                 # length
                  110,111,112,26,113,114,45,45,45,45)); # abc\nde
    my $shell = shell_new($setup, 'mgrep');
    shell_add_args($shell, '-w', 'a', $file_name);
    assert_contains shell_call($shell), 'TO: host, all but player 3';
};

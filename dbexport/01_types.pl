#!/usr/bin/perl -w
#
#  dbexport: test types
#
use strict;
use c2systest;

test 'dbexport/01_types', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_start_wait($setup);

    # Prepare database
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'set', 'a', 1);
    conn_call($dbc, 'set', 'b', 'word');
    conn_call($dbc, 'hset', 'c', 'k', 'hash1');
    conn_call($dbc, 'hset', 'c', 'j', 'hash2');
    conn_call($dbc, 'sadd', 'd', 3);
    conn_call($dbc, 'sadd', 'd', 1);
    conn_call($dbc, 'sadd', 'd', 5);
    conn_call($dbc, 'rpush', 'e', 'x');
    conn_call($dbc, 'rpush', 'e', 'y');
    conn_call($dbc, 'rpush', 'e', 'z');

    # Export
    my $ex = shell_new($setup, 'dbexport');
    shell_add_args($ex, 'db', '"*"');
    my $result = shell_call($ex);
    $result =~ s/ +/ /g;
    assert_equals $result, join("\n",
                                "silent redis set a 1",
                                "silent redis set b word",
                                "silent redis hset c j hash2",
                                "silent redis hset c k hash1",
                                "silent redis sadd d 1",
                                "silent redis sadd d 3",
                                "silent redis sadd d 5",
                                "silent redis rpush e x",
                                "silent redis rpush e y",
                                "silent redis rpush e z",
                                "");
};

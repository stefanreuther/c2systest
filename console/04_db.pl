#!/usr/bin/perl -w
#
#  Console: access to database
#
use strict;
use c2systest;

# exit: causes following code to not be executed
test 'console/04_db', sub {
    # Start environment
    my $setup = shift;
    my $dbs = setup_add_db($setup);
    setup_start_wait($setup);

    # Talk to db
    my $shell = shell_new($setup, 'console');
    assert shell_call($shell, "redis set kk vv\n") =~ /result="OK"/;
    assert shell_call($shell, "redis get kk\n")    =~ /result="vv"/;

    # Verify that we see what shell did
    my $dbc = service_connect($dbs);
    assert_equals conn_call($dbc, 'get', 'kk'), 'vv';

    # Verify that we can do things the shell sees
    conn_call($dbc, 'sadd', 'someset', 'u');
    conn_call($dbc, 'sadd', 'someset', 'v');
    conn_call($dbc, 'sadd', 'someset', 'w');
    assert shell_call($shell, "redis scard someset\n") =~ /result="?3"?/;  # respserver returns '"3"', redis-server returns '3'

    # Composability
    shell_call($shell, "redis smembers someset | foreach i {redis set k\$i 1}\n");
    assert_equals conn_call($dbc, 'get', 'ku'), 1;

    # Same thing, with regular contexts
    shell_call($shell, "redis\nsmembers someset | foreach i {set q\$i 1}\n");
    assert_equals conn_call($dbc, 'get', 'qu'), 1;
};

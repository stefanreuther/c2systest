#!/usr/bin/perl -w
#
#  dbexport: test quoting
#
use strict;
use c2systest;

test 'dbexport/02_quote', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_start_wait($setup);

    # Prepare database
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'set', 'a', 1);
    conn_call($dbc, 'set', 'b', 'word');
    conn_call($dbc, 'set', 'c', 'text with space');
    conn_call($dbc, 'set', 'd', "apos'trophe");
    conn_call($dbc, 'set', 'e', 'quo"te');
    conn_call($dbc, 'set', 'f', "It's \"great\"!");
    conn_call($dbc, 'set', 'g', "a{b,c}d");
    conn_call($dbc, 'set', 'h', "a<b<c");
    conn_call($dbc, 'set', 'i', "new\nline");
    conn_call($dbc, 'set', 'j', "\xFF\x01\xC2");
    conn_call($dbc, 'set', 'k', "\xC2\xA0");

    # Export
    my $ex = shell_new($setup, 'dbexport');
    shell_add_args($ex, 'db', '"*"');
    my $result = shell_call($ex);
    $result =~ s/ +/ /g;
    assert_equals $result, join("\n",
                                "silent redis set a 1",
                                "silent redis set b word",
                                "silent redis set c \"text with space\"",
                                "silent redis set d \"apos'trophe\"",
                                "silent redis set e 'quo\"te'",
                                "silent redis set f \"It's \\\"great\\\"!\"",
                                "silent redis set g \"a{b,c}d\"",
                                "silent redis set h \"a<b<c\"",
                                "silent redis set i \"new\\nline\"",
                                "silent redis set j \"\\xFF\\x01\\xC2\"",
                                "silent redis set k \"\\xC2\\xA0\"",
                                "");
};

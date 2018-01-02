#!/usr/bin/perl -w
#
#  Console: test empty loop
#
use strict;
use c2systest;

test 'console/05_emptyloop', sub {
    # We need a database that provides the "empty list" result we need
    my $setup = shift;
    setup_add_db($setup);
    setup_start_wait($setup);

    # Command
    my $shell = shell_new($setup, 'console');
    assert_contains shell_call($shell, "redis smembers xx | foreach i {exit}\necho ok\n"), "ok\n";
};

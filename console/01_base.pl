#!/usr/bin/perl -w
#
#  Console: basic test
#
use strict;
use c2systest;

# Test that invocation of the console works
test 'console/01_base', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    assert_equals shell_call($shell), '';
    assert_equals shell_call($shell, "echo hi\n"), "hi\n";
    assert_equals shell_call($shell, "echo hi"), "hi\n";        # fails in -classic
};

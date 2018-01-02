#!/usr/bin/perl -w
#
#  Console: error detection
#
use strict;
use c2systest;

# Test that detection of errors works
test 'console/01_base', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');
    my $cmd = "asldjkaw298uilasd\n";

    # Error capture is disabled by default
    assert_equals shell_call($shell, $cmd), '';     # Fails in -classic, which prints errors to stdout

    # Capture errors
    assert shell_call($shell, $cmd, want_error => 1) =~ /ERROR:/;
};

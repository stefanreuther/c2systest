#!/usr/bin/perl -w
#
#  Console: global commands
#
use strict;
use c2systest;

# exit: causes following code to not be executed
test 'console/03_global/exit', sub {
    my $setup = shift; 
    my $shell = shell_new($setup, 'console');

    # Simple case
    assert_equals shell_call($shell, "exit\necho foo\n"), "";
    assert_equals shell_call($shell, "..\necho foo\n"), "";
    assert_equals shell_call($shell, "up\necho foo\n"), "";

    # Exit within macro still leaves the shell
    assert_equals shell_call($shell, "macro a {exit\necho foo}\na\necho foo"), "";
};

# load
test 'console/03_global/load', sub {
    my $setup = shift; 
    my $shell = shell_new($setup, 'console');
    my $tmp = setup_get_tmpfile_name($setup, 'loadee');

    open FILE, ">", $tmp or die "$tmp: $!";
    print FILE "echo hi\n";
    close FILE;

    # Execute
    assert_equals shell_call($shell, "load '$tmp'\n"), "hi\n";
};

# die: causes the program to exit with a message
test 'console/03_global/die', sub {
    my $setup = shift; 
    my $shell = shell_new($setup, 'console');

    assert_equals shell_call($shell, "die boom\necho foo\n", expect_exit => 256), "";
};

# fatal: causes the program to exit with a message on error
test 'console/03_global/fatal', sub {
    my $setup = shift; 
    my $shell = shell_new($setup, 'console');

    # Test
    # - 'badcommand' fails because it's not recognized
    # - 'if' fails because of missiing parameters
    assert_equals shell_call($shell, "fatal badcommand\necho foo\n", expect_exit => 256), "";
    assert_equals shell_call($shell, "fatal if\necho foo\n", expect_exit => 256), "";

    # Cross-check
    my $res = shell_call($shell, "badcommand\necho foo\n", want_error => 1);
    assert $res =~ /ERROR:/;
    assert $res =~ /foo/;

    $res = shell_call($shell, "int\necho foo\n", want_error => 1);
    assert $res =~ /ERROR:/;
    assert $res =~ /foo/;
};

# noerror: causes the program to NOT exit
test 'console/03_global/noerror', sub {
    my $setup = shift; 
    my $shell = shell_new($setup, 'console');

    # Test
    assert_equals shell_call($shell, "noerror badcommand\necho foo\n"), "foo\n";
    assert_equals shell_call($shell, "noerror if\necho foo\n"), "foo\n";
};

# silent: causes no result be printed
test 'console/03_global/silent', sub {
    my $setup = shift; 
    my $shell = shell_new($setup, 'console');

    # Test
    assert_equals shell_call($shell, "silent int 1\n"), "";

    # Cross-check
    assert_equals shell_call($shell, "int 1\n"), "result=1\n";
};


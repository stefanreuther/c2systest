#!/usr/bin/perl -w
#
#  Console: test for string commands
#
#  Vaguely synchronized with TestServerConsoleStringCommandHandler, 20171013
#
use strict;
use c2systest;

# TestServerConsoleStringCommandHandler::testStr: Test "str"
test 'console/50_string/str', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # Error cases
    assert is_error(shell_call($shell, lines('str'),     want_error => 1));
    assert is_error(shell_call($shell, lines('str x y'), want_error => 1));

    # Success cases
    assert_equals shell_call($shell, lines('int xxxx | str')), lines('result=""');
    assert_equals shell_call($shell, lines('str aa')), lines('result="aa"');
    assert_equals shell_call($shell, lines('int 7 | str')), lines('result="7"');
};

# TestServerConsoleStringCommandHandler::testStrEq: Test "str_eq".
test 'console/50_string/str_eq', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # Error cases
    assert is_error(shell_call($shell, lines('str_eq'),       want_error => 1));
    assert is_error(shell_call($shell, lines('str_eq a'),     want_error => 1));
    assert is_error(shell_call($shell, lines('str_eq a b c'), want_error => 1));

    # Success cases
    assert_equals shell_call($shell, lines('str_eq aaa aaa')), lines('result=1');
    assert_equals shell_call($shell, lines('str_eq aaa AAA')), lines('result=0');
    assert_equals shell_call($shell, lines('str_eq aaa ""')), lines('result=0');
    assert_equals shell_call($shell, lines('str_eq aaa q')), lines('result=0');
    assert_equals shell_call($shell, lines('int 3 | str_eq aaa')), lines('result=0');
    assert_equals shell_call($shell, lines('int 3 | str_eq "3"')), lines('result=1');
};

# TestServerConsoleStringCommandHandler::testStrEmpty: Test "str_empty".
test 'console/50_string/str_empty', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # This fails in -classic which returns "result=True"/"False".
    assert_equals shell_call($shell, lines('str_empty')), lines('result=1');
    assert_equals shell_call($shell, lines('int xx | str_empty')), lines('result=1');
    assert_equals shell_call($shell, lines('str_empty "" "" ""')), lines('result=1');
    assert_equals shell_call($shell, lines('str_empty a b c')), lines('result=0');
    assert_equals shell_call($shell, lines('str_empty "" b ""')), lines('result=0');
    assert_equals shell_call($shell, lines('str_empty a "" c')), lines('result=0');
};

sub lines {
    join ('', map {"$_\n"} @_);
}

sub is_error {
    $_[0] =~ /ERROR:/;
}


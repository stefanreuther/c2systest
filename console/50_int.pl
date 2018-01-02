#!/usr/bin/perl -w
#
#  Console: test for integer commands
#
#  Vaguely synchronized with TestServerConsoleIntegerCommandHandler, 20171013
#
use strict;
use c2systest;

# TestServerConsoleIntegerCommandHandler::testInt: test "int"
test 'console/50_int/int', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # Error cases
    assert is_error(shell_call($shell, lines('int'),     want_error => 1));
    assert is_error(shell_call($shell, lines('int 1 2'), want_error => 1));

    # Success cases
    assert_equals shell_call($shell, lines('int 42')), lines('result=42');
    assert_equals shell_call($shell, lines('int zzz')), lines();
    assert_equals shell_call($shell, lines('int zzz | int')), lines();
};

# TestServerConsoleIntegerCommandHandler::testIntNot: test "int_not".
test 'console/50_int/int_not', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # Error cases
    assert is_error(shell_call($shell, lines('int_not'),     want_error => 1));
    assert is_error(shell_call($shell, lines('int_not 1 2'), want_error => 1));

    # Success cases
    assert_equals shell_call($shell, lines('int zzz | int_not')), lines();
    assert_equals shell_call($shell, lines('int_not 7')), lines('result=0');
    assert_equals shell_call($shell, lines('int_not 0')), lines('result=1');
};

# TestServerConsoleIntegerCommandHandler::testIntAdd: test "int_add".
test 'console/50_int/int_add', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # Success cases
    assert_equals shell_call($shell, lines('int_add')), lines('result=0');
    assert_equals shell_call($shell, lines('int_add 10 7 200 4000')), lines('result=4217');

    # Error case
    assert is_error(shell_call($shell, lines('int_add 10 7 boo! 4000'), want_error => 1));
};

# TestServerConsoleIntegerCommandHandler::testIntSeq: test "int_seq".
test 'console/50_int/int_seq', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # Error cases
    assert is_error(shell_call($shell, lines('int_seq'),       want_error => 1));
    assert is_error(shell_call($shell, lines('int_seq 1 2 3'), want_error => 1));

    # Normal cases
    assert_equals shell_call($shell, lines('int_seq 2 5')), lines('result=[',
                                                                  '  2,',
                                                                  '  3,',
                                                                  '  4,',
                                                                  '  5',
                                                                  ']');
    assert_equals shell_call($shell, lines('int_seq 5 5')), lines('result=[',
                                                                  '  5',
                                                                  ']');
    assert_equals shell_call($shell, lines('int_seq 6 5')), lines('result=[ ]');
};

sub lines {
    join ('', map {"$_\n"} @_);
}

sub is_error {
    $_[0] =~ /ERROR:/;
}

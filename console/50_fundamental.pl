#!/usr/bin/perl -w
#
#  Console: test for fundamental commands
#
#  Vaguely synchronized with TestServerConsoleFundamentalCommandHandler, 20171013
#
use strict;
use c2systest;

# Test 'echo'
test 'console/50_fundamental/echo', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # TestServerConsoleFundamentalCommandHandler::testEcho
    assert_equals shell_call($shell, lines('echo')), lines('');
    assert_equals shell_call($shell, lines('echo xyz')), lines('xyz');
    assert_equals shell_call($shell, lines('echo xyz -8 q')), lines('xyz -8 q');
};

# Test 'foreach'
test 'console/50_fundamental/foreach', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # TestServerConsoleFundamentalCommandHandler::testForEach: normal operation
    assert_equals shell_call($shell, lines('foreach i {echo $i} a b c')), lines(qw(a b c));

    # TestServerConsoleFundamentalCommandHandler::testForEachPreserve: preserve iteration variable
    assert_equals shell_call($shell, lines('setenv i x', 'foreach i {echo $i} a b c', 'echo $i')), lines(qw(a b c x));

    # TestServerConsoleFundamentalCommandHandler::testForEachError: previous value in iteration variable preserved even in case of error
    my $output = shell_call($shell, lines('setenv i old_value', 'foreach i {if} a b c', 'echo $i'));
    assert $output =~ /old_value/;

    # TestServerConsoleFundamentalCommandHandler::testForEachUnrecognized: unrecognized command
    $output = shell_call($shell, lines('setenv i old_value', 'foreach i {badcommand} a b c', 'echo $i'));
    assert $output =~ /old_value/;
};

# Test 'if'
test 'console/50_fundamental/if', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # TestServerConsoleFundamentalCommandHandler::testIf
    assert_equals shell_call($shell, lines('if {int 1} {echo ok}')), lines('ok');

    # TestServerConsoleFundamentalCommandHandler::testIfFalse
    assert_equals shell_call($shell, lines('if {int 0} {echo ok}')), '';

    # TestServerConsoleFundamentalCommandHandler::testIfElse
    assert_equals shell_call($shell, lines('if {int 1} {echo ok} else {echo fail}')), lines('ok');

    # TestServerConsoleFundamentalCommandHandler::testIfElseFalse
    assert_equals shell_call($shell, lines('if {int 0} {echo fail} else {echo ok}')), lines('ok');

    # TestServerConsoleFundamentalCommandHandler::testIfElsif
    assert_equals shell_call($shell, lines('if {int 0} {echo fail} elsif {int 1} {echo ok} elsif {int 1} {echo fail}')), lines('ok');

    # TestServerConsoleFundamentalCommandHandler::testIfElsifFalse
    assert_equals shell_call($shell, lines('if {int 0} {echo fail} elsif {int 0} {echo fail} elsif {int 0} {echo fail}')), '';

    # TestServerConsoleFundamentalCommandHandler::testIfMultiline
    assert_equals shell_call($shell, lines('if {',
                                           '  int 0',
                                           '  int 1',
                                           '} {',
                                           '  echo t1',
                                           '  echo t2',
                                           '}')), lines(qw(t1 t2));
};

# Test 'env', 'setenv'
test 'console/50_fundamental/env', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');

    # Initial state
    assert_equals shell_call($shell, lines('echo $i')), lines('');
    assert_equals shell_call($shell, lines('env')), lines('result=[ ]');

    # Setting
    assert_equals shell_call($shell, lines('setenv i zz',
                                           'echo a$ie')), lines('azze');

    # TestServerConsoleFundamentalCommandHandler::testEnv
    assert_equals shell_call($shell, lines('setenv i 52',
                                           'setenv s q',
                                           'env')),
          lines('result=[',
                '  "i",',
                '  "52",',
                '  "s",',
                '  "q"',
                ']');
};

# Test errors
test 'console/50_fundamental/errors', sub {
    my $setup = shift;
    my $shell = shell_new($setup, 'console');
    shell_set_options($shell, want_error => 1);

    # Unrecognized
    assert is_error(shell_call($shell, lines('set a b')));

    # Parameter count
    assert is_error(shell_call($shell, lines('env x')));          # fails in -classic
    assert is_error(shell_call($shell, lines('setenv')));
    assert is_error(shell_call($shell, lines('setenv x')));
    assert is_error(shell_call($shell, lines('if')));
    assert is_error(shell_call($shell, lines('if a')));
    assert is_error(shell_call($shell, lines('if {int 0} a b')));
    assert is_error(shell_call($shell, lines('if {int 0} a else')));
    assert is_error(shell_call($shell, lines('if {int 0} a elsif')));
    assert is_error(shell_call($shell, lines('if {int 0} a elsif {int 1}')));
};


sub lines {
    join ('', map {"$_\n"} @_);
}

sub is_error {
    $_[0] =~ /ERROR:/;
}

#!/usr/bin/perl -w
#
#  Export: bug 358, suboptimal error messages
#
use strict;
use c2systest;

# Syntax error: command line error causes "-t" to be interpreted as a field list.
# This is an invalid field list that can be detected directly.
test 'export/90_358_error/syntax', sub {
    my $setup = shift;
    my $export = shell_new($setup, 'export');
    shell_add_args($export, qw(-f -t csv data/game -P));
    my $result = shell_call($export, '', expect_exit => 256, want_error => 1);

    # Output will be: "c2export: '-f -t': Syntax error"
    assert_contains $result, 'yntax error';
};

# Missing directory name: should report the name of the directory being tried in the error message.
test 'export/90_358_error/dir', sub {
    my $setup = shift;
    my $export = shell_new($setup, 'export');
    my $name = setup_get_tmpfile_name($setup, 'canary');
    mkdir $name, 0777 or die;
    shell_add_args($export, '-P', $name);
    my $result = shell_call($export, '', expect_exit => 256, want_error => 1);

    # Output will be: "c2export: no game data found in directory "/tmp/c2sys4652/canary""
    assert_contains $result, 'canary';
};

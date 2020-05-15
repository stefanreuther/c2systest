#!/usr/bin/perl -w
#
#  c2plugin: conflict checks (uninstall)
#
use strict;
use c2systest;

# Test removing a plugin that still is needed.
# Must be rejected.
test 'plugin/02_conflict_rm/regular', sub {
    my $setup = shift;
    setup_two_plugins($setup);

    # Regular invocation
    my $sh = shell_new($setup, 'plugin');
    shell_add_args($sh, 'rm', 'a');
    my $output = shell_call($sh, '', expect_exit=>256, want_error=>1);
    assert_contains $output, 'is required by the following plugins';
    assert_contains $output, 'B (Bee)';
};

# Test removing a plugin that still is needed, using '-f'.
# Must succeed.
test 'plugin/02_conflict_rm/force', sub {
    my $setup = shift;
    setup_two_plugins($setup);
    assert_execution_succeeds(setup_get_required_system_config($setup, 'c2plugin.path')." rm -f a");
};

# # Test removing a plugin that still is needed, using '-f', alternate syntax.
# # Must succeed.
# test 'plugin/02_conflict_rm/force2', sub {
#     my $setup = shift;
#     setup_two_plugins($setup);
#     assert_execution_succeeds(setup_get_required_system_config($setup, 'c2plugin.path')." rm a -f");
# };

# Test removing a plugin that does not exist.
# Must be rejected.
test 'plugin/02_conflict_rm/nx', sub {
    my $setup = shift;
    setup_two_plugins($setup);

    # Regular invocation
    my $sh = shell_new($setup, 'plugin');
    shell_add_args($sh, 'rm', 'q');
    my $output = shell_call($sh, '', expect_exit=>256, want_error=>1);
    assert_contains $output, 'is not known';
};

# Test removing both dependant plugins, in correct order.
# Must succeed.
test 'plugin/02_conflict_rm/both', sub {
    my $setup = shift;
    setup_two_plugins($setup);
    assert_execution_succeeds(setup_get_required_system_config($setup, 'c2plugin.path')." rm b a");
};


# Common setup:
# Sets up an installation with two plugins, A and B, where A provides a feature that B needs.
sub setup_two_plugins {
    my $setup = shift;
    my $home = setup_add_home($setup);
    mkdir "$home/.pcc2", 0777;    # bug #229: PCC2 fails if profile does not exist

    my $prog = setup_get_required_system_config($setup, 'c2plugin.path');

    my $a = setup_get_tmpfile_name($setup, 'a.c2p');
    file_put($a, "provides = thefeature");
    assert_execution_succeeds("$prog add $a");

    my $b = setup_get_tmpfile_name($setup, 'b.c2p');
    file_put($b, "requires = thefeature\nname = Bee");
    assert_execution_succeeds("$prog add $b");
}

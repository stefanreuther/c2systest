#!/usr/bin/perl -w
#
#  c2plugin: conflict checks (install)
#
use strict;
use c2systest;

# Test installing a plugin that requires a feature we don't have.
# Must be rejected.
test 'plugin/01_conflict/missing', sub {
    my $setup = shift;
    my $home = setup_add_home($setup);
    mkdir "$home/.pcc2", 0777;    # bug #229: PCC2 fails if profile does not exist

    my $plugin = setup_get_tmpfile_name($setup, 'a.c2p');
    file_put($plugin, "requires = reqfeat\n");

    my $sh = shell_new($setup, 'plugin');
    shell_add_args($sh, 'add', $plugin);
    my $output = shell_call($sh, '', expect_exit=>256, want_error=>1);
    assert_contains $output, 'requires the following features';
    assert_contains $output, 'REQFEAT';
};

# Test installing a plugin that requires a feature we have in an old version.
# Must be rejected.
test 'plugin/01_conflict/old', sub {
    my $setup = shift;
    my $home = setup_add_home($setup);
    mkdir "$home/.pcc2", 0777;    # bug #229: PCC2 fails if profile does not exist

    my $old_plugin = setup_get_tmpfile_name($setup, 'old.c2p');
    file_put($old_plugin, "provides = versfeat 1.0");
    assert_execution_succeeds(setup_get_required_system_config($setup, 'c2plugin.path')." add $old_plugin");

    my $plugin = setup_get_tmpfile_name($setup, 'a.c2p');
    file_put($plugin, "requires = versfeat 1.5\n");

    my $sh = shell_new($setup, 'plugin');
    shell_add_args($sh, 'add', $plugin);
    my $output = shell_call($sh, '', expect_exit=>256, want_error=>1);
    assert_contains $output, 'requires the following features';
    assert_contains $output, 'VERSFEAT 1.5';
};

# Test installing a plugin that provides a feature we already have.
# Must be rejected.
test 'plugin/01_conflict/exist', sub {
    my $setup = shift;
    my $home = setup_add_home($setup);
    mkdir "$home/.pcc2", 0777;    # bug #229: PCC2 fails if profile does not exist

    my $old_plugin = setup_get_tmpfile_name($setup, 'old.c2p');
    file_put($old_plugin, "provides = exfeat");
    assert_execution_succeeds(setup_get_required_system_config($setup, 'c2plugin.path')." add $old_plugin");

    my $plugin = setup_get_tmpfile_name($setup, 'a.c2p');
    file_put($plugin, "provides = exfeat\n");

    my $sh = shell_new($setup, 'plugin');
    shell_add_args($sh, 'add', $plugin);
    my $output = shell_call($sh, '', expect_exit=>256, want_error=>1);
    assert_contains $output, 'conflicts with the following plugins';
    assert_contains $output, 'OLD (OLD)';
};

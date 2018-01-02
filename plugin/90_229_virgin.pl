#!/usr/bin/perl -w
#
#  c2plugin: bug 229, installation on virgin system
#  As of 20170926, fails on classic.
#
use strict;
use c2systest;

test 'plugin/90_229_virgin', sub {
    my $setup = shift;

    # Make a temporary directory to use as $HOME
    my $home = setup_get_tmpfile_name($setup, 'home');
    mkdir $home, 0777 or die;
    $ENV{HOME} = $home;

    # Create a temporary plugin
    my $plugin = setup_get_tmpfile_name($setup, 'file.c2p');
    my $content = "Name = testplugin\n";
    open PLUGIN, '>', $plugin or die;
    print PLUGIN $content;
    close PLUGIN;

    # Execute
    my $prog = setup_get_required_system_config($setup, 'c2plugin.path');
    assert_execution_succeeds "$prog add $plugin";

    # Verify result
    assert -d "$home/.pcc2";
    assert -d "$home/.pcc2/plugins";
    assert_equals file_content("$home/.pcc2/plugins/file.c2p"), $content;
};

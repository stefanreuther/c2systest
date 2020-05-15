#!/usr/bin/perl -w
#
#  Interactive test: default-initialized services
#

use strict;
use c2systest;
use c2cgitest;
use POSIX ('getcwd');

test 'interactive/x02_default', sub {
    my $setup = shift;

    # Fetch/verify environment (also see console/x02_init_ng)
    my $console_tool = setup_get_required_system_config($setup, 'c2console.path');
    my $root_dir = setup_get_required_system_config($setup, 'c2ng');
    my $prog_path = setup_get_required_system_config($setup, 'programs');
    if ($console_tool !~ m|^/|) {
        $console_tool = getcwd() . '/' . $console_tool;
    }
    if (! -d "$root_dir/server/scripts") {
        $root_dir = "$root_dir/../share";
    }
    assert -f "$root_dir/server/scripts/init.con";

    # Setup system
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_add_host($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_add_app($setup, 'format', 'c2format');
    setup_start_wait($setup);

    # Initialize
    assert_execution_succeeds "cd $root_dir/server/scripts && $console_tool load init.con";
    assert_execution_succeeds "cd $prog_path && $console_tool load install.con";

    # Serve
    setup_serve($setup);
};

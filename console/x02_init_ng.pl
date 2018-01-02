#!/usr/bin/perl -w
#
#  Initialisation: ng
#
#  This test invokes the initialisation routine on an isolated setup,
#  and saves the result into a directory "x02_init_ng".
#  This can serve as the basis of a regression test for the installation routine.
#
#  This test only works in the "ng" configuration
#
#  WARNING: if "x02_init_ng" already exists, it is removed and re-created.
#
use strict;
use c2systest;
use POSIX();

test 'console/x02_init_ng', sub {
    # Prepare
    my $setup = shift;
    my $dir_name = "x02_init_ng";
    my $export_tool = setup_get_required_system_config($setup, 'c2dbexport.path');
    my $console_tool = setup_get_required_system_config($setup, 'c2console.path');
    my $root_dir = setup_get_required_system_config($setup, 'c2ng');
    if ($console_tool !~ m|^/|) {
        $console_tool = POSIX::getcwd() . '/' . $console_tool;
    }

    # Start it
    assert_execution_succeeds "rm -rf $dir_name && mkdir $dir_name";
    assert mkdir "$dir_name/user";
    assert mkdir "$dir_name/host";
    setup_add_host($setup);
    setup_add_hostfile($setup, "$dir_name/host");
    setup_add_userfile($setup, "$dir_name/user");
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Pre-verify
    assert -f "$root_dir/server/scripts/init.con";

    # Perform the installation routine
    assert_execution_succeeds "cd $root_dir/server/scripts && $console_tool load init.con";

    # Export the database
    assert_execution_succeeds "$export_tool db '*' >$dir_name/dbcontent.txt";

    # Save all files
    assert_execution_succeeds "find $dir_name/user $dir_name/host -type f | sort | xargs cat >$dir_name/filecontent.txt";

    # Do it again and prove idempotence
    assert_execution_succeeds "cd $root_dir/server/scripts && $console_tool load init.con";
    assert_execution_succeeds "$export_tool db '*' >$dir_name/dbcontent2.txt";
    assert_execution_succeeds "find $dir_name/user $dir_name/host -type f | sort | xargs cat >$dir_name/filecontent2.txt";
    assert_execution_succeeds "diff -q $dir_name/dbcontent.txt $dir_name/dbcontent2.txt";
    assert_execution_succeeds "diff -q $dir_name/filecontent.txt $dir_name/filecontent2.txt";

    # Only dbcontent.txt is required for manual introspection.
    unlink "$dir_name/filecontent.txt", "$dir_name/filecontent2.txt", "$dir_name/dbcontent2.txt";

    # Verify
    # c2console-ng had a bug in piping making the init script database keys 'user:#<vector>:...'.
    assert file_content("$dir_name/dbcontent.txt") !~ /#</;
};

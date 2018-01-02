#!/usr/bin/perl -w
#
#  Program Installation
#
#  This test invokes the "programs" installation routine on an insolated setup,
#  and saves the result into a directory "x01_install_dir".
#  This can serve as the basis of a regression test for the installation routine.
#
#  WARNING: if "x01_install_dir" already exists, it is removed and re-created.
#
use strict;
use c2systest;
use POSIX();

test 'console/x01_install', sub {
    # Prepare
    my $setup = shift;
    my $dir_name = "x01_install_dir";
    my $export_tool = setup_get_required_system_config($setup, 'c2dbexport.path');
    my $console_tool = setup_get_required_system_config($setup, 'c2console.path');
    my $prog_path = setup_get_required_system_config($setup, 'programs');
    if ($console_tool !~ m|^/|) {
        $console_tool = POSIX::getcwd() . '/' . $console_tool;
    }

    # Start it
    assert_execution_succeeds "rm -rf $dir_name && mkdir $dir_name";
    setup_add_host($setup);
    setup_add_hostfile($setup, $dir_name);
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Preparations
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(mkdir tools));
    conn_call($hfc, qw(mkdir shiplist));

    # Perform the installation routine
    assert_execution_succeeds "cd $prog_path && $console_tool load install.con";

    # Export the database
    assert_execution_succeeds "$export_tool db 'prog:*' >$dir_name/dbcontent.txt";

    # Save all files
    assert_execution_succeeds "find $dir_name/tools $dir_name/shiplist -type f | sort | xargs cat >$dir_name/filecontent.txt";

    # Do it again and prove idempotence
    assert_execution_succeeds "cd $prog_path && $console_tool load install.con";
    assert_execution_succeeds "$export_tool db 'prog:*' >$dir_name/dbcontent2.txt";
    assert_execution_succeeds "find $dir_name/tools $dir_name/shiplist -type f | sort | xargs cat >$dir_name/filecontent2.txt";
    assert_execution_succeeds "diff -q $dir_name/dbcontent.txt $dir_name/dbcontent2.txt";
    assert_execution_succeeds "diff -q $dir_name/filecontent.txt $dir_name/filecontent2.txt";

    # Only dbcontent.txt is required for manual introspection.
    unlink "$dir_name/filecontent.txt", "$dir_name/filecontent2.txt", "$dir_name/dbcontent2.txt";
};

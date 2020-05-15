#!/usr/bin/perl -w
#
#  c2check: test check on all turn files available on a PlanetsCentral host tree
#
#  This does not fail, only print the failing turns.
#  We actually have a few failing turns in the archive.
#
#  Pass the directory of a hostfile filespace as a parameter "-Dhostdata=...".
#  This will first scan the directories, then process each directory as a testcase,
#  checking all available turn files in each.
#
#  As of 20180210, we have 2157 turns.
#

use strict;
use c2systest;
use c2service;

my @todo = find_game_directories();

foreach my $e (@todo) {
    test "check/x01_everything$e->[0]", sub {
        my $setup = shift;

        # Prepare a directory
        my $dir = setup_get_tmpfile_name($setup, 'gd');
        mkdir $dir, 0700 or die "$dir: $!";
        copy_files($dir, $e->[2], $e->[3]);      # 'pre' archive
        copy_files($dir, $e->[1], $e->[3]);      # 'trn' archive

        # Invoke c2check for all players
        foreach my $pl (1 .. 11) {
            if (-f "$dir/player$pl.trn") {
                my $shell = shell_new($setup, 'check');
                shell_add_args($shell, $pl, $dir, '-r', '-p');
                my $result = shell_call($shell, undef, ignore_exit => 1);
                if ($result =~ /BALANCE|RANGE|INVALID|CHECKSUM|SYNTAX|FATAL|WARNING/) {
                    print trace_color("34;1", 
                                      "Turn file detected as invalid:\n  Player $pl\n  Directory $e->[1]\nOutput:\n$result\n");
                }
            }
        }
    };
}



sub find_game_directories {
    my $setup = setup_create();
    my $root = setup_get_required_system_config($setup, 'hostdata');
    setup_destroy($setup);

    my @queue = ($root);
    my @result;
    while (@queue) {
        my $path = shift @queue;
        if (opendir DIR, $path) {
            while (defined(my $e = readdir(DIR))) {
                if ($e =~ /^\./) {
                    # skip
                } elsif ($e =~ /^trn-(\d+)$/ && -d "$path/$e" && -d "$path/pre-$1") {
                    push @result, [substr($path, length($root)).'/'.$1, "$path/$e", "$path/pre-$1", 0];
                } elsif ($e =~ /^trn-(\d+)\.tgz$/ && -f "$path/$e" && -f "$path/pre-$1.tgz") {
                    push @result, [substr($path, length($root)).'/'.$1, "$path/$e", "$path/pre-$1.tgz", 1];
                } elsif ($e =~ /^trn-\d+/) {
                    trace_test("Suspicious directory entry: $path/$e");
                } elsif (-d "$path/$e") {
                    push @queue, "$path/$e";
                } else {
                    # skip
                }
            }
            closedir DIR;
        }
    }

    my $n = scalar(@result);
    trace_test("Found $n test cases");

    sort {$a->[0] cmp $b->[0]} @result;
}


sub copy_files {
    my ($dest, $src, $compressed) = @_;
    if ($compressed) {
        assert_execution_succeeds "(cd $dest && tar xz) < $src";
    } else {
        assert_execution_succeeds "cp $src/* $dest/";
    }
}

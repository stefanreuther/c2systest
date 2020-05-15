#!/usr/bin/perl -w
#
#  c2check: basic test
#

use c2systest;
use c2service;

# Test basic functionality.
# A: Create a directory containing a game, invoke c2check.
# E: Execution must succeed.
test 'check/01_base', sub {
    my $setup = shift;

    # Create game directory
    my $dir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $dir, 0777 or die "$dir: $!";
    foreach (qw(beamspec.dat engspec.dat hullspec.dat pconfig.src planet.nm player7.rst torpspec.dat truehull.dat xyplan.dat)) {
        file_put("$dir/$_", file_content("data/game2/$_"));
    }
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03"));

    # Create shell command
    my $shell = shell_new($setup, 'check');
    shell_add_args($shell, 7, $dir, '-r', '-c');
    my $shell_result = shell_call($shell);
    my $log_result = file_content("$dir/check.log");
    assert_contains $shell_result, 'Turn is OK';
    assert_contains $log_result, 'Turn is OK';
    assert_equals index($shell_result, 'CHECKSUM'), -1;
    assert_equals index($log_result, 'CHECKSUM'), -1;
};

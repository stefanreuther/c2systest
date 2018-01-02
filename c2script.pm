#!/usr/bin/perl -w
#
#  Testing c2script
#
package c2script;

use c2systest;
use strict;
use bytes;

# setup_call_script_on_game($setup, $game, $script, opt=>val: call script
#   $setup   = setup object
#   $game    = game directory name ("data/game")
#   $script  = script text
#   opt=>val = additional parameters to shell_call
sub setup_call_script_on_game {
    my ($setup, $game, $script, @args) = @_;

    # Create game directory
    my $tmp_game = setup_get_tmpfile_name($setup, 'g'.setup_count($setup));
    mkdir $tmp_game, 0777 or die "$tmp_game: $!";
    opendir GAME, $game or die "$game: $!";
    while (defined(my $entry = readdir(GAME))) {
        if ($entry !~ /^\./ && -f "$game/$entry") {
            file_put("$tmp_game/$entry", file_content("$game/$entry"));
        }
    }
    close GAME;

    # Create script
    my $tmp_script = setup_get_tmpfile_name($setup, 't'.setup_count($setup).'.q');
    file_put($tmp_script, $script);

    # Create shell
    my $shell = shell_new($setup, 'script');
    shell_add_args($shell, '-G', $tmp_game, $tmp_script, '-q');
    shell_call($shell, undef, @args);
}

1;

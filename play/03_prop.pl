#!/usr/bin/perl -w
#
#  c2play-server: properties
#
#  Properties are a simple way to get out-of-band information into a game process
#  for consumption by the JavaScript (e.g. the link to a host game number).
#  However, as of 20190512, this ability was never used.
#
#  c2server runs on c2file's filespace and will parse .c2file for properties.
#  c2play-server provides '-D' options instead.
#
use strict;
use c2systest;

# Test properties.
# A: set up a game directory and start c2play-server, passing it some properties. Retrieve obj/main.
# E: server correctly executed, correct properties returned.
test 'play/03_prop', sub {
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $dir, 0777 or die "$dir: $!";
    file_put("$dir/player3.rst", file_content("data/game/player3.rst"));

    my $shell = shell_new($setup, 'server');
    # As of 20190512, shell_add_args does not properly deal with spaces, so we need to quote here.
    shell_add_args($shell, $dir, 3, '-DGAME.NR=17', '-DEMPTY', '-DGAME.NAME="This Is The Name"');

    my @out = split /\n/, shell_call($shell, "GET obj/main\n");
    assert_starts_with shift(@out), '100';
    assert_starts_with shift(@out), '200';
    assert_equals pop(@out), '.';

    my $data = json_parse(join("\n", @out));
    assert_equals $data->{main}{'TURN'}, 131;
    assert_equals $data->{main}{'TURN.DATE'}, '06-01-2012';

    my $prop = $data->{main}{PROP};
    assert_equals $prop->{'GAME.NR'}, 17;
    assert_equals $prop->{'EMPTY'}, '';
    assert_equals $prop->{'GAME.NAME'}, 'This Is The Name';
};

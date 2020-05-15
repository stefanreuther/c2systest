#!/usr/bin/perl -w
#
#  c2play-server (c2server) basic test
#
use strict;
use c2systest;

# Test basic operation.
# A: set up a game directory and start c2play-server. Retrieve obj/main.
# E: server correctly executed, correct values returned.
test 'play/01_base', sub {
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $dir, 0777 or die "$dir: $!";
    file_put("$dir/player3.rst", file_content("data/game/player3.rst"));

    my $shell = shell_new($setup, 'server');
    shell_add_args($shell, $dir, 3);

    my @out = split /\n/, shell_call($shell, "GET obj/main\n");
    assert_starts_with shift(@out), '100';
    assert_starts_with shift(@out), '200';
    assert_equals pop(@out), '.';

    my $data = json_parse(join("\n", @out));
    assert_equals $data->{main}{'TURN'}, 131;
    assert_equals $data->{main}{'TURN.DATE'}, '06-01-2012';

    # PHost only recognized by c2ng version:
    assert_equals $data->{main}{'SYSTEM.HOST'}, 'PHost';
};

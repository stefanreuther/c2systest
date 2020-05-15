#!/usr/bin/perl -w
#
#  Router: simple test
#
#  Basic functionality test: tests that we can start sessions and
#  retrieve information from them.
#
use strict;
use c2systest;

test 'router/02_simple', sub {
    # Config
    my $setup = shift;
    setup_add_service_config($setup, 'router.filenotify' => 0);
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));

    # Prepare directory
    my $gamedir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $gamedir, 0777 or die;
    file_put("$gamedir/player3.rst", file_content('data/game/player3.rst'));

    # Add router
    my $rs = setup_add_router($setup);

    # Start
    setup_start($setup);

    # Create a session
    my $sid = parse_session(service_call_raw($rs, "NEW $gamedir 3\n"));

    # Fetch content
    my ($head, $body) = split /\n/, service_call_raw($rs, "S $sid\nGET obj/main\n"), 2;
    assert_starts_with $head, 200;

    my $parsed_body = json_parse($body);
    assert_equals $parsed_body->{main}{'SYSTEM.HOST'}, 'PHost';
    assert_equals $parsed_body->{main}{'TURN'}, 131;
};


sub parse_session {
    my $x = shift;
    assert $x =~ /^201 (\S+) /;
    $1;
}

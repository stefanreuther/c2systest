#!/usr/bin/perl -w
#
#  talk: sanity check. Checks that we can start/stop services as required.
#  If this fails, other tests will most likely also fail.
#

use c2systest;
use strict;

test 'talk/00_sanity/db', sub {
    # Test just the database
    my $setup = shift;
    my $db = setup_add_db($setup);
    setup_start($setup);
    conn_call(service_connect_wait($db), 'PING');
};

test 'talk/00_sanity/talk', sub {
    my $setup = shift;
    setup_add_db($setup);
    my ($talk, $mailout) = setup_add_apps($setup, 'talk', 'mailout');

    # Start
    setup_start($setup);

    # Ping everyone
    conn_call(service_connect_wait($talk),    'PING');
    conn_call(service_connect_wait($mailout), 'PING');

    # Ping talk with multiple connections. Use raw connect because we know the service is there.
    my $x = service_connect($talk);
    my $y = service_connect($talk);
    my $z = service_connect($talk);
    conn_call($x, 'PING');
    conn_call($y, 'PING');
    conn_call($z, 'PING');
};

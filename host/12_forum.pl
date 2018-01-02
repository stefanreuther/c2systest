#!/usr/bin/perl -w
#
#  Host: creation of forums
#
use strict;
use c2systest;
use c2service;

# Create/rename/finish a game and check that the forum is managed correctly.
test 'host/12_forum', sub {
    my $setup = shift;
    prepare($setup);

    # Create some tools
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'hostadd', 'h', '', '', 'h');
    conn_call($hc, 'masteradd', 'm', '', '', 'm');
    conn_call($hc, 'shiplistadd', 's', '', '', 's');

    # Create a game
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetname', $gid, 'Wolf 359 Battle');
    conn_call($hc, 'gamesetstate', $gid, 'joining');

    # At this point, a forum must have been created.
    # Because we have no other forums, that will be forum #1.
    my $fid = conn_call($hc, 'gameget', $gid, 'forum');
    assert_equals $fid, 1;

    # Inquire the forum
    my $tc = setup_connect_app($setup, 'talk');
    assert_equals conn_call($tc, 'forumget', $fid, 'name'),      'Wolf 359 Battle';
    assert_equals conn_call($tc, 'forumget', $fid, 'key'),       'wolf 003359 battle';
    assert_equals conn_call($tc, 'forumget', $fid, 'parent'),    'active';
    assert_equals conn_call($tc, 'forumget', $fid, 'newsgroup'), 'planetscentral.games.1-wolf-359-battle';

    my %g = @{ conn_call($tc, 'groupls', 'active') };
    assert_equals ref($g{forums}), 'ARRAY';
    assert_equals scalar(@{$g{forums}}), 1;
    assert_equals $g{forums}[0], $fid;

    # Rename the game. This will rename the game (but not the newsgroup).
    conn_call($hc, 'gamesetname', $gid, 'Picard wins');
    assert_equals conn_call($tc, 'forumget', $fid, 'name'),      'Picard wins';
    assert_equals conn_call($tc, 'forumget', $fid, 'newsgroup'), 'planetscentral.games.1-wolf-359-battle';

    # Finish the game. This will move the forum.
    conn_call($hc, 'gamesetstate', $gid, 'finished');
    assert_equals conn_call($tc, 'forumget', $fid, 'parent'), 'finished';
};



sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup);
    setup_add_host($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    c2service::setup_hostfile_add_defaults($setup);
}

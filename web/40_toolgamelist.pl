#!/usr/bin/perl -w
#
#  Test toolinfo.cgi, tool filters
#

use strict;
use c2systest;
use c2cgitest;


# Positive test: tool filter
test 'web/40_toolgamelist/tool', sub {
    my $setup = shift;
    positive_test($setup, 'tool/T');
};

# Positive test: host filter
test 'web/40_toolgamelist/host', sub {
    my $setup = shift;
    positive_test($setup, 'host/H');
};

# Positive test: shiplist filter
test 'web/40_toolgamelist/shiplist', sub {
    my $setup = shift;
    positive_test($setup, 'shiplist/S');
};

# Positive test: master filter
test 'web/40_toolgamelist/master', sub {
    my $setup = shift;
    positive_test($setup, 'master/M');
};

# Negative test: host filter
test 'web/40_toolgamelist/mismatch/host', sub {
    my $setup = shift;

    # Setup
    prepare($setup);
    add_default_tools($setup);
    my $gid = add_game($setup);
    assert_equals $gid, 1;

    # Request list
    my $cgi = cgi_new($setup, 'host/toolinfo.cgi');
    cgi_set_path($cgi, "/host/P/games");
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);
    assert $html;
    assert $html->{links}{"/host/toolinfo.cgi/host/P"};
    assert !$html->{links}{"/host/game.cgi/1-The-Game"};
};

# Negative test: non-public game
test 'web/40_toolgamelist/mismatch/status', sub {
    my $setup = shift;

    # Setup
    prepare($setup);
    add_default_tools($setup);
    my $gid = add_game($setup);
    assert_equals $gid, 1;

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'gamesettype', $gid, 'unlisted');

    # Request list
    my $cgi = cgi_new($setup, 'host/toolinfo.cgi');
    cgi_set_path($cgi, "/host/H/games");
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);
    assert $html;
    assert $html->{links}{"/host/toolinfo.cgi/host/H"};
    assert !$html->{links}{"/host/game.cgi/1-The-Game"};

};



# Test fragment for positive test
sub positive_test {
    my ($setup, $frag) = @_;

    # Setup
    prepare($setup);
    add_default_tools($setup);
    my $gid = add_game($setup);
    assert_equals $gid, 1;

    # Request list
    my $cgi = cgi_new($setup, 'host/toolinfo.cgi');
    cgi_set_path($cgi, "/$frag/games");
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);
    assert $html;
    assert $html->{links}{"/host/toolinfo.cgi/$frag"};
    assert $html->{links}{"/host/game.cgi/1-The-Game"};
}

sub prepare {
    my $setup = shift;
    setup_add_host($setup, '--nocron');
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Create 'games'. Required for -classic.
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(mkdirhier games));
}

sub add_default_tools {
    my $setup = shift;
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hmset prog:host:prog:H kind host path Hp description Hinfo));
    conn_call($db, qw(hmset prog:host:prog:P kind host path Pp description Pinfo));
    conn_call($db, qw(hmset prog:master:prog:M kind master path Mp description Minfo));
    conn_call($db, qw(hmset prog:sl:prog:S kind shiplist path Sp description Sinfo));
    conn_call($db, qw(hmset prog:tool:prog:T path Tp description Tinfo));
    conn_call($db, qw(set prog:host:default H));
    conn_call($db, qw(set prog:master:default M));
    conn_call($db, qw(set prog:sl:default S));
    conn_call($db, qw(sadd prog:host:list H));
    conn_call($db, qw(sadd prog:host:list P));
    conn_call($db, qw(sadd prog:master:list M));
    conn_call($db, qw(sadd prog:sl:list S));
    conn_call($db, qw(sadd prog:tool:list T));
}

sub add_game {
    my $setup = shift;
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gamesetstate', $gid, 'joining');
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gameaddtool', $gid, 'T');
    conn_call($hc, 'gamesetname', $gid, 'The Game');

    $gid;
}

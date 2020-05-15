#!/usr/bin/perl -w
#
#  NNTP: Command tests
#
use strict;
use c2systest;

# Test all commands in a short scenario
test 'nntp/03_commands/all', sub {
    my $setup = shift;
    prepare($setup);

    # Login
    my $nnc = setup_connect_app($setup, 'nntp');
    assert_differs conn_interact($nnc, undef), '';
    assert_starts_with conn_interact($nnc, 'authinfo user a'), '381';
    assert_starts_with conn_interact($nnc, 'authinfo pass z'), '281';

    # Ignored
    assert_starts_with conn_interact($nnc, 'mode reader'), '200';

    # Lists
    my $active = ("ng.forum 0 1 y\n".
                  "ng.news 3 1 n\n".
                  "ng.talk 0 1 y\n");
    assert_equals conn_interact($nnc, 'list', qw{^215}), $active;
    assert_equals conn_interact($nnc, 'list active', qw{^215}), $active;
    assert_equals conn_interact($nnc, 'list subscriptions', qr{^215}), "ng.talk\nng.news\n";
    assert_equals conn_interact($nnc, 'list newsgroups', qr{^215}), ("ng.forum Some other forum\n".
                                                                     "ng.news News and announcements\n".
                                                                     "ng.talk Chatter\n");
    assert conn_interact($nnc, 'list overview.fmt', qr{^215}) =~ /Xref/;

    # Group
    assert_starts_with conn_interact($nnc, 'group ng.talk'), '211 0 0 0 ng.talk';
    assert_starts_with conn_interact($nnc, 'group ng.news'), '211 3 1 3 ng.news';

    # Group content
    assert_equals conn_interact($nnc, 'listgroup', qr{^211}), "1\n2\n3\n";
    assert_equals conn_interact($nnc, 'listgroup ng.talk', qr{^211}), "";
    assert_equals conn_interact($nnc, 'listgroup', qr{^211}), "";
    assert_equals conn_interact($nnc, 'listgroup ng.news', qr{^211}), "1\n2\n3\n";

    # Articles
    assert_starts_with conn_interact($nnc, 'stat 1'), '223';
    assert_equals conn_interact($nnc, 'body 1', qr{^222}), "News body\n\n";
    assert conn_interact($nnc, 'head 1', qr{^221}) =~ /Subject: News title/;
    assert conn_interact($nnc, 'head 1', qr{^221}) =~ /Message-Id: <1.1\@fqdn>/;
    assert conn_interact($nnc, 'article 1', qr{^220}) =~ /Message-Id: <1.1\@fqdn>/;
    assert conn_interact($nnc, 'article 1', qr{^220}) =~ /News body/;

    # Overview
    my @stuff = split /\t/, conn_interact($nnc, 'over 2', qw{^224});
    assert_equals $stuff[0], '2';                                # sequence
    assert_equals $stuff[1], 'Re: News title';                   # subject
    assert_equals $stuff[2], 'O. Neill <one@invalid.invalid>';   # from
    assert_equals $stuff[4], '<2.2@fqdn>';                       # message id
    assert_equals $stuff[5], '<1.1@fqdn>';                       # references
    assert_equals $stuff[6], '41';                               # bytes
    assert_equals $stuff[7], '2';                                # lines
    assert_equals $stuff[8], "Xref: pathhost ng.news:2\n";       # Xref
};

# Test article access with implicit numbering
test 'nntp/03_commands/implicit', sub {
    my $setup = shift;
    prepare($setup);

    # Login
    my $nnc = setup_connect_app($setup, 'nntp');
    assert_differs conn_interact($nnc, undef), '';
    assert_starts_with conn_interact($nnc, 'authinfo user a'), '381';
    assert_starts_with conn_interact($nnc, 'authinfo pass z'), '281';

    # Select group
    assert_starts_with conn_interact($nnc, 'group ng.news'), '211 3 1 3 ng.news';

    # Fetch bodies, with implicit counting
    assert_equals conn_interact($nnc, 'body', qr{^222}), "News body\n\n";
    assert_starts_with conn_interact($nnc, 'stat 3'), '223';
    assert_equals conn_interact($nnc, 'body', qr{^222}), "> News body\n\nOther reply\n\n";
};

# Test article access with message Id
test 'nntp/03_commands/id', sub {
    my $setup = shift;
    prepare($setup);

    # Login
    my $nnc = setup_connect_app($setup, 'nntp');
    assert_differs conn_interact($nnc, undef), '';
    assert_starts_with conn_interact($nnc, 'authinfo user a'), '381';
    assert_starts_with conn_interact($nnc, 'authinfo pass z'), '281';

    # Fetch bodies, with implicit counting
    assert_equals conn_interact($nnc, 'body <2.2@fqdn>', qr{^222}), "> News body\n\nNews reply\n\n";
};


sub prepare {
    my $setup = shift;
    setup_add_service_config($setup, 'user.key', 'xyz');
    setup_add_service_config($setup, 'talk.msgid', '@fqdn');
    setup_add_service_config($setup, 'talk.path', 'pathhost');
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_add_nntp($setup);
    setup_start_wait($setup);

    # Preload database
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'set',  'user:1001:name', 'one');
    conn_call($db, 'hset', 'user:1001:profile', 'screenname', 'O. Neill');

    conn_call($db, 'set',  'user:1009:name', 'a');
    conn_call($db, 'hset', 'user:1009:profile', 'screenname', 'Alf');
    conn_call($db, 'set',  'user:1009:password', '1,52YluJAXWKqqhVThh22cNw');
    conn_call($db, 'set',  'uid:a', '1009');

    # Preload forum
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'groupadd', 'root', 'key', 'root');
    assert_equals conn_call($tc, 'forumadd', parent => 'root', name => 'News',  description => 'News and announcements', newsgroup => 'ng.news',  readperm => 'all', writeperm => '-all', key => '02'), 1;
    assert_equals conn_call($tc, 'forumadd', parent => 'root', name => 'Talk',  description => 'Chatter',                newsgroup => 'ng.talk',  readperm => 'all', writeperm => 'all',  key => '01'), 2;
    assert_equals conn_call($tc, 'forumadd',                   name => 'Other', description => 'Some other forum',       newsgroup => 'ng.forum', readperm => 'all', writeperm => 'all',  key => '00'), 3;

    assert_equals conn_call($tc, 'postnew',   1, 'News title', 'forum:News body', 'user', 1001), 1;
    assert_equals conn_call($tc, 'postreply', 1, 'Re: News title', 'forum:[quote]News body[/quote] News reply', 'user', 1001), 2;
    assert_equals conn_call($tc, 'postreply', 1, 'Re: News title', 'forum:[quote]News body[/quote] Other reply', 'user', 1009), 3;
}

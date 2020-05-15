#!/usr/bin/perl -w
#
#  Performance test for userinfo.cgi
#
#  20190101  26525 ms    Original
#  20190325  26310 ms    Replace redis dependency by individual microservices
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

my @FULL_PROFILE = (inforealnameflag => 1,
                    infoemailflag => 1,
                    screenname => 'Joseph',
                    email => 'joe@provi.der',
                    infocountry => '<<Neuland>>',
                    infotown => '<<Horstenlochnitz>>',
                    infooccupation => '<<Schluckimpfer>>',
                    infobirthday => '<<May 35>>',
                    infowebsite => '<<http://x.y/>>');


test 'web/p27_userinfo', sub {
    # Prepare
    my $setup = shift;
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_usermgr($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_add_talk($setup);
    setup_add_host($setup);
    setup_start_wait($setup);

    # Create and populate user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, qw(adduser joe secret), @FULL_PROFILE);

    # Mark email confirmed
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'email:joe@provi.der:status', 'status/'.$uid, 'c');

    # Invoke user-info page from another user
    my $uid2 = conn_call($uc, qw(adduser jack secret));
    my $cookie = setup_make_cookie($setup, $uid2);

    test_timing 'web userinfo', sub {
        my $cgi = cgi_new($setup, 'userinfo.cgi');
        cgi_add_cookie($cgi, $cookie);
        cgi_set_path($cgi, "/joe");
        my $result = cgi_run($cgi);
        assert_contains $result->{text}, '<li class="navtrail-self">Joseph</li>';
    };
};

#!/usr/bin/perl -w
#
#  Test password upgrade
#
#  This tests that hashes are created in/upgraded to "2," format
#  (SaltedPasswordEncrypter) even when the database contains them
#  in "1," (ClassicEncrypter) format.
#
use strict;
use c2systest;

# Test hash upgrade on successful login
# A: preload database with old hash. Log in with correct password.
# E: hash upgraded
test 'user/02_pwupgrade/success', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.key', 'xyz');
    setup_start_wait($setup);

    my $db = setup_connect_app($setup, 'db');
    my $umc = setup_connect_app($setup, 'user');

    # Preload DB
    my $enc_pw = '1,52YluJAXWKqqhVThh22cNw';
    conn_call($db, 'set', 'user:1009:password', $enc_pw);
    conn_call($db, 'set', 'uid:a_b', '1009');
    conn_call($db, 'set', 'uid:root', '0');

    # Log in successfully
    assert_equals conn_call($umc, 'login', 'a_b', 'z'), 1009;

    # Hash must have been changed
    my $new_pw = conn_call($db, 'get', 'user:1009:password');
    assert_differs $enc_pw, $new_pw;
    assert_starts_with $new_pw, "2,";

    # Log in again; hash must remain
    assert_equals conn_call($umc, 'login', 'A_B', 'z'), 1009;
    assert_equals conn_call($umc, 'login', 'A->B', 'z'), 1009;
    assert_equals conn_call($db, 'get', 'user:1009:password'), $new_pw;
};

# Test hash upgrade on unsuccessful login
# A: preload database with old hash. Log in with incorrect password.
# E: hash unchanged
test 'user/02_pwupgrade/fail', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.key', 'xyz');
    setup_start_wait($setup);

    my $db = setup_connect_app($setup, 'db');
    my $umc = setup_connect_app($setup, 'user');

    # Preload DB
    my $enc_pw = '1,52YluJAXWKqqhVThh22cNw';
    conn_call($db, 'set', 'user:1009:password', $enc_pw);
    conn_call($db, 'set', 'uid:a_b', '1009');
    conn_call($db, 'set', 'uid:root', '0');

    # Log in unsuccessfully: hash must remain same
    assert_throws sub{ assert_equals conn_call($umc, 'login', 'a_b', 'qq') }, 401;
    assert_equals conn_call($db, 'get', 'user:1009:password'), $enc_pw;
};

# Test hash upgrade on password change.
# A: preload database with old hash. Change password.
# E: new hash created in upgraded format
test 'user/02_pwupgrade/passwd', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.key', 'xyz');
    setup_start_wait($setup);

    my $db = setup_connect_app($setup, 'db');
    my $umc = setup_connect_app($setup, 'user');

    # Preload DB
    my $enc_pw = '1,52YluJAXWKqqhVThh22cNw';
    conn_call($db, 'set', 'user:1009:password', $enc_pw);
    conn_call($db, 'set', 'uid:a_b', '1009');
    conn_call($db, 'set', 'uid:root', '0');

    # Change password
    assert_equals conn_call($umc, 'passwd', '1009', 'ff'), 'OK';

    # Hash must have been changed
    my $new_pw = conn_call($db, 'get', 'user:1009:password');
    assert_differs $enc_pw, $new_pw;
    assert_starts_with $new_pw, "2,";

    # Log in with new password
    assert_equals conn_call($umc, 'login', 'A_B', 'ff'), 1009;
    assert_equals conn_call($umc, 'login', 'A->B', 'ff'), 1009;
    assert_equals conn_call($db, 'get', 'user:1009:password'), $new_pw;

    # Old password fails
    assert_throws sub{ assert_equals conn_call($umc, 'login', 'a_b', 'z') }, 401;
};

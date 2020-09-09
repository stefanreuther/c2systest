#!/usr/bin/perl -w
#
#  Test keystore
#
use strict;
use c2systest;
use c2service;

my $TIME = "06-01-201222:46:01";

my $KEYPFX = "\x5E\x04\0\0\x36\x07\0\0\xE7\x09\0\0\x80\x06\0\0\x50\x14\0\0\xE8\x20\0\0\x7B\x22\0\0\xB0\x2C\0\0\x29\x2E\0\0\xE8\x3A\0\0\x3D\x40\0\0\x80\x13\0\0\xEB\x4B\0\0\xF0\x49\0\0\xE3\x49\0\0\xA0\x5C\0\0\x31\x57\0\0\xC6\x6C\0\0\x97\x5D\0\0\xC8\x73\0\0\xB5\x6B\0\0\xC0\x23\0\0\x60\x25\0\0\0\x27\0\0\xA0\x28\0\0";
my $KEY1 = $KEYPFX."\xCF\x03\0\0\x42\x0A\0\0\x6F\x12\0\0\x80\x06\0\0\x71\x0C\0\0\xC0\x09\0\0\x60\x0B\0\0\0\x0D\0\0\xA0\x0E\0\0\x40\x10\0\0\xE0\x11\0\0\x80\x13\0\0\x20\x15\0\0\xC0\x16\0\0\x60\x18\0\0\0\x1A\0\0\xA0\x1B\0\0\x40\x1D\0\0\xE0\x1E\0\0\x80\x20\0\0\x20\x22\0\0\xC0\x23\0\0\x60\x25\0\0\0\x27\0\0\xA0\x28\0\0\x22\x61\x07\0";
my $KEY2 = $KEYPFX."\xCF\x03\0\0\x42\x0A\0\0\x6F\x12\0\0\x80\x06\0\0\xB2\x0C\0\0\xC0\x09\0\0\x60\x0B\0\0\0\x0D\0\0\xA0\x0E\0\0\x40\x10\0\0\xE0\x11\0\0\x80\x13\0\0\x20\x15\0\0\xC0\x16\0\0\x60\x18\0\0\0\x1A\0\0\xA0\x1B\0\0\x40\x1D\0\0\xE0\x1E\0\0\x80\x20\0\0\x20\x22\0\0\xC0\x23\0\0\x60\x25\0\0\0\x27\0\0\xA0\x28\0\0\x63\x61\x07\0";
my $KEY3 = $KEYPFX."\xCF\x03\0\0\x42\x0A\0\0\x6F\x12\0\0\x80\x06\0\0\xF3\x0C\0\0\xC0\x09\0\0\x60\x0B\0\0\0\x0D\0\0\xA0\x0E\0\0\x40\x10\0\0\xE0\x11\0\0\x80\x13\0\0\x20\x15\0\0\xC0\x16\0\0\x60\x18\0\0\0\x1A\0\0\xA0\x1B\0\0\x40\x1D\0\0\xE0\x1E\0\0\x80\x20\0\0\x20\x22\0\0\xC0\x23\0\0\x60\x25\0\0\0\x27\0\0\xA0\x28\0\0\xA4\x61\x07\0";


# Test retrieval of stored keys
# A: prepare some keys in filespace, some in database.
# E: 'keyls' retrieves them all
test 'host/24_keystore/get', sub {
    my $setup = shift;
    prepare($setup);

    my $uid = c2service::setup_add_user($setup, 'fred');
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, 'mkdir', 'u/fred/dir1');
    conn_call($ufc, 'put',   'u/fred/dir1/fizz.bin', to_key_file($KEY1));
    conn_call($ufc, 'mkdir', 'u/fred/dir2');
    conn_call($ufc, 'put',   'u/fred/dir2/fizz.bin', to_key_file($KEY2));

    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'sadd',  "user:$uid:key:all", 'xyzzy');
    conn_call($dbc, 'hmset', "user:$uid:key:id:xyzzy", useCount => 7, blob => $KEY3, lastUsed => 999);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'user', $uid);
    my $list = conn_call($hc, 'keyls');

    assert_equals scalar(@$list), 3;
    foreach (@$list) {
        my %e = @$_;
        if ($e{key2} eq 'Key 1') {
            assert_equals $e{filePathName}, 'u/fred/dir1';
        } elsif ($e{key2} eq 'Key 2') {
            assert_equals $e{filePathName}, 'u/fred/dir2';
        } elsif ($e{key2} eq 'Key 3') {
            assert !$e{filePathName};
            assert_equals $e{gameUseCount}, 7;
        } else {
            assert_failure "key2 has unexpected value '$e{key2}'";
        }
    }
};

# Test capturing of uploaded keys.
# A: prepare a game; upload a turn
# E: 'keyls' contains turn file's key
test 'host/24_keystore/capture', sub {
    my $setup = shift;
    prepare($setup);

    my $uid = c2service::setup_add_user($setup, 'fred');
    my $gid = prepare_game($setup);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'playerjoin', $gid, 1, $uid);
    conn_call($hc, 'user', $uid);

    # Initial list is empty
    my $list = conn_call($hc, 'keyls');
    assert_equals scalar(@$list), 0;

    # Upload a turn
    conn_call($hc, 'trn', c2service::vp_make_turn(1, $TIME));

    # Key now listed
    $list = conn_call($hc, 'keyls');
    assert_equals scalar(@$list), 1;

    my %e = @{$list->[0]};
    assert_equals $e{gameUseCount}, 1;
};



sub prepare {
    my $setup = shift;
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Defaults for host
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);
    c2service::setup_host_add_phost($setup, 'H', setup_get_required_system_config($setup, 'programs').'/phost-4.1h');

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');
}

sub prepare_game {
    my $setup = shift;

    # Create game
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');

    # Patch database
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'set', "game:bytime:$TIME", $gid);
    conn_call($dbc, 'set', "game:$gid:state", 'running');
    conn_call($dbc, 'smove', 'game:state:preparing', 'game:state:running', $gid);
}

sub to_key_file {
    return ("\0" x 136) . $_[0];
}

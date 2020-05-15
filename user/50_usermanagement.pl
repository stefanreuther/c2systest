#!/usr/bin/perl -w
#
#  Test basic user management
#
use strict;
use c2systest;

# TestServerUserUserManagement::testCreation: Test creation of a user.
test 'user/50_usermanagement/create', sub {
    # Environment
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Testee
    my $umc = setup_connect_app($setup, 'user');

    # Create a user. Must succeed.
    my @config = ('realname', 'John Doe', 'createua', 'wget/1.16');
    my $id = conn_call($umc, 'adduser', 'joe', 'secret', @config);
    assert_differs $id, '';

    # Creating same user again fails
    assert_throws sub{ conn_call($umc, 'adduser', 'joe', 'other', @config) }, 409;

    # Creating a different user works
    my $id2 = conn_call($umc, 'adduser', 'joe2', 'other', @config);
    assert_differs $id, $id2;

    # Cross-check
    assert_equals conn_call($umc, 'lookup', 'joe'), $id;
    assert_equals conn_call($umc, 'name', $id), 'joe';
    assert_list_equals conn_call($umc, 'mname', $id), ['joe'];
    assert_equals conn_call($umc, 'login', 'joe', 'secret'), $id;
    assert_throws sub{ conn_call($umc, 'login', 'joe', 'other') }, 401;

    assert_equals conn_call($umc, 'get', $id, 'screenname'), 'joe';
    assert_equals conn_call($umc, 'get', $id, 'createua'), 'wget/1.16';
    assert !defined conn_call($umc, 'get', $id, 'fancy');
};

# TestServerUserUserManagement::testName: Test user name handling.
test 'user/50_usermanagement/name', sub {
    # Environment
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Testee
    my $umc = setup_connect_app($setup, 'user');

    # Valid names
    my $id = conn_call($umc, 'adduser', 'joe random', 'foo');
    assert_equals conn_call($umc, 'get', $id, 'screenname'), 'joe random';
    assert_equals conn_call($umc, 'name', $id), 'joe_random';

    $id = conn_call($umc, 'adduser', '-=fancy=-', 'foo');
    assert_equals conn_call($umc, 'get', $id, 'screenname'), '-=fancy=-';
    assert_equals conn_call($umc, 'name', $id), 'fancy';

    $id = conn_call($umc, 'adduser', 'H4XoR', 'foo');
    assert_equals conn_call($umc, 'get', $id, 'screenname'), 'H4XoR';
    assert_equals conn_call($umc, 'name', $id), 'h4xor';

    $id = conn_call($umc, 'adduser', '  hi  ', 'foo');
    assert_equals conn_call($umc, 'get', $id, 'screenname'), '  hi  ';
    assert_equals conn_call($umc, 'name', $id), 'hi';

    # Invalid names
    assert_throws sub{ conn_call($umc, 'adduser', '-=#=-', 'foo') }, 401;
    assert_throws sub{ conn_call($umc, 'adduser', '', 'foo') }, 401;
};

# TestServerUserUserManagement::testBlockedName: Test handling blocked names.
test 'user/50_usermanagement/blocked', sub {
    # Environment
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Block a user name
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'set', 'uid:root', 0);

    # Testee
    my $umc = setup_connect_app($setup, 'user');

    # Allocating this name fails
    assert_throws sub{ conn_call($umc, 'adduser', 'root', 'foo') }, 409;

    # Logging in fails
    assert_throws sub{ conn_call($umc, 'login', 'root', 'foo') }, 401;

    # Looking it up fails
    assert_throws sub{ conn_call($umc, 'lookup', 'root') }, 404;
};

# TestServerUserUserManagement::testProfile: Test profile handling.
test 'user/50_usermanagement/profile', sub {
    # Environment
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Default profile
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(hmset default:profile default1 1 default2 2));
    conn_call($dbc, qw(hmset default:profilecopy copy1 1 copy2 2));

    # Create a user
    my $umc = setup_connect_app($setup, 'user');
    my $id = conn_call($umc, qw(adduser otto w screenname Ottilie default1 7 copy2 9));

    # Update profiles
    conn_call($dbc, qw(hmset default:profile default1 11 default2 12));
    conn_call($dbc, qw(hmset default:profilecopy copy1 11 copy2 12));

    # Verify individual items
    # - screenname normally set from parameter, overriden from config
    assert_equals conn_call($umc, 'get', $id, 'screenname'), "Ottilie";

    # - default1 explicitly mentioned in config
    assert_equals conn_call($umc, 'get', $id, 'default1'), "7";

    # - default2 taken from changed default
    assert_equals conn_call($umc, 'get', $id, 'default2'), "12";

    # - copy1 taken from default:profilecopy at time of account creation
    assert_equals conn_call($umc, 'get', $id, 'copy1'), "1";

    # - copy2 explicitly mentioned in config
    assert_equals conn_call($umc, 'get', $id, 'copy2'), "9";
};

# TestServerUserUserManagement::testLogin (ex TestServerTalkTalkNNTP::testLogin): Test login
test 'user/50_usermanagement/login', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);

    my $preload_db = sub {
        my $setup = shift;
        my $db = setup_connect_app($setup, 'db');
        conn_call($db, 'set', 'user:1009:password', '1,52YluJAXWKqqhVThh22cNw');
        conn_call($db, 'set', 'uid:a_b', '1009');
        conn_call($db, 'set', 'uid:root', '0');
    };

    # First test
    {
        setup_add_service_config($setup, 'user.key', 'xyz');
        setup_start_wait($setup);
        $preload_db->($setup);
        my $umc = setup_connect_app($setup, 'user');

        # Success cases
        assert_equals conn_call($umc, 'login', 'a_b', 'z'), 1009;
        assert_equals conn_call($umc, 'login', 'A_B', 'z'), 1009;
        assert_equals conn_call($umc, 'login', 'A->B', 'z'), 1009;

        # Error cases
        assert_throws sub{ conn_call($umc, 'login', 'root', '')    }, 401;
        assert_throws sub{ conn_call($umc, 'login', 'a_b',  '')    }, 401;
        assert_throws sub{ conn_call($umc, 'login', 'a_b',  'zzz') }, 401;
        assert_throws sub{ conn_call($umc, 'login', 'a_b',  'Z')   }, 401;
        assert_throws sub{ conn_call($umc, 'login', '',     'Z')   }, 401;
        assert_throws sub{ conn_call($umc, 'login', '/',    'Z')   }, 401;

        setup_stop($setup);
    }

    # Second test, with different user key. This must make the test fail
    {
        setup_add_service_config($setup, 'user.key', 'abc');
        setup_start_wait($setup);
        $preload_db->($setup);
        my $umc = setup_connect_app($setup, 'user');

        assert_throws sub{ conn_call($umc, 'login', 'a_b', 'z')    }, 401;
        assert_throws sub{ conn_call($umc, 'login', 'root', '')    }, 401;
        setup_stop($setup);
    }
};

# TestServerUserUserManagement::testProfileLimit
test 'user/50_usermanagement/limit', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.profile.maxvaluesize', 5);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # Create a user. Must succeed.
    my $id = conn_call($umc, 'adduser', 'joe_luser', 'secret', realname => 'John', createua => 'wget/1.16');
    assert_differs $id, '';

    # Verify created profile
    assert_equals conn_call($umc, 'get', $id, 'realname'), 'John';
    assert_equals conn_call($umc, 'get', $id, 'createua'), 'wget/';
    assert_equals conn_call($umc, 'get', $id, 'screenname'), 'joe_l';

    # Update profile
    conn_call($umc, 'set', $id, infotown => 'York', infooccupation => 'Whatever');
    assert_equals conn_call($umc, 'get', $id, 'infotown'), 'York';
    assert_equals conn_call($umc, 'get', $id, 'infooccupation'), 'Whate';
};

# TestServerUserUserManagement::testProfileNoLimit
test 'user/50_usermanagement/nolimit', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.profile.maxvaluesize', 0);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # Create a user. Must succeed.
    my $id = conn_call($umc, 'adduser', 'joe_luser', 'secret', realname => 'John', createua => 'wget/1.16');
    assert_differs $id, '';

    # Verify created profile
    assert_equals conn_call($umc, 'get', $id, 'realname'), 'John';
    assert_equals conn_call($umc, 'get', $id, 'createua'), 'wget/1.16';
};

# TestServerUserUserManagement::testProfileDefaultLimit
test 'user/50_usermanagement/default', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # Create a user. Must succeed.
    my $id = conn_call($umc, 'adduser', 'joe_luser', 'secret', 
                       realname => 'John',
                       infotown => 'X' x 20000);
    assert_differs $id, '';

    # Verify created profile
    assert_equals conn_call($umc, 'get', $id, 'realname'), 'John';
    assert_starts_with conn_call($umc, 'get', $id, 'infotown'), 'X' x 1000;
};

# TestServerUserUserManagement::testRemove
test 'user/50_usermanagement/remove', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # Create a user. Must succeed.
    my $id = conn_call($umc, 'adduser', 'joe', 'secret', infotown => 'Arrakis', screenname => 'Jonathan');
    assert_differs $id, '';

    # Verify profile content
    assert_equals conn_call($umc, 'lookup', 'joe'), $id;
    assert_equals conn_call($umc, 'name', $id), 'joe';
    assert_equals conn_call($umc, 'login', 'joe', 'secret'), $id;
    assert_equals conn_call($umc, 'get', $id, 'screenname'), 'Jonathan';

    # Create a token
    my $tok = conn_call($umc, 'maketoken', $id, 'api');
    assert_differs $tok, '';
    my %tok_info = conn_call_list($umc, 'checktoken', $tok);
    assert_equals $tok_info{user}, $id;
    assert_equals $tok_info{type}, 'api';

    # Remove the user
    conn_call($umc, 'deluser', $id);
    assert_throws sub{ conn_call($umc, 'lookup', 'joe') }, 404;
    assert_equals conn_call($umc, 'name', $id), '';
    assert_throws sub{ conn_call($umc, 'login', 'joe', 'secret') }, 401;
    assert_equals conn_call($umc, 'get', $id, 'screenname'), '(joe)';

    my $t = conn_call($umc, 'get', $id, 'infotown');
    assert !defined($t) || $t eq '';

    # Token must be gone
    assert_throws sub{ conn_call($umc, 'checktoken', $tok) }, 410;

    # Create another joe. Must succeed and create a different Id.
    my $id2 = conn_call($umc, 'adduser', 'joe', 'secret', infotown => 'Corrino', screenname => 'Joseph');
    assert_differs $id, $id2;
    assert_differs $id2, '';
    assert_equals conn_call($umc, 'lookup', 'joe'), $id2;
    assert_equals conn_call($umc, 'name', $id2), 'joe';
};

#!/usr/bin/perl -w
#
#  Database sanity tests
#
#  Production runs against redis; tests typically run against InternalDatabase.
#  This tests the commands that we use in -classic and -ng.
#  In particular, we don't use ZSets or expiration (yet).
#
use strict;
use c2systest;

# Basic commands: PING
test 'self/02_db/base', sub {
    my $db = prepare(@_);
    assert_equals conn_call($db, qw(ping)), 'PONG';
};

# Key commands: DEL, EXISTS, KEY, RENAME, RENAMENX, TYPE
test 'self/02_db/key', sub {
    my $db = prepare(@_);

    # Empty
    assert_equals conn_call($db, qw(exists a)), 0;
    assert_throws sub{ conn_call($db, qw(rename a b)) };
    assert_throws sub{ conn_call($db, qw(renamenx a b)) };

    # Create 'a'
    conn_call($db, qw(set a va));
    assert_equals conn_call($db, qw(exists a)), 1;

    # Rename 'a' -> 'b'
    conn_call($db, qw(rename a b));
    assert_equals conn_call($db, qw(exists b)), 1;

    # Create 'x', try to rename 'b' to 'x', then 'y' (ending with 'x', 'y')
    conn_call($db, qw(set x va));
    assert_equals conn_call($db, qw(renamenx b x)), 0;
    assert_equals conn_call($db, qw(renamenx b y)), 1;

    # Check type
    assert_equals conn_call($db, qw(type y)), 'string';

    # Check keys
    assert_set_equals conn_call($db, qw(keys *)), ['x', 'y'];

    # Delete
    assert_equals conn_call($db, qw(del y)), 1;
    assert_equals conn_call($db, qw(del y)), 0;
    assert_equals conn_call($db, qw(exists y)), 0;
};

# String commands: APPEND, GET, GETRANGE, GETSET, MSET, SET, SETNX, STRLEN
test 'self/02_db/string', sub {
    my $db = prepare(@_);

    # Create some values
    conn_call($db, qw(set v1 one));
    conn_call($db, qw(mset v2 two v3 three));

    # get
    assert_equals conn_call($db, qw(get v1)), 'one';
    assert_equals conn_call($db, qw(getset v1 first)), 'one';
    assert_equals conn_call($db, qw(get v1)), 'first';

    # get/getset on undefined
    assert !defined conn_call($db, qw(getset v4 four));
    assert !defined conn_call($db, qw(get v5)), '';

    # append
    conn_call($db, qw(append v4 th));
    assert_equals conn_call($db, qw(get v4)), 'fourth';

    # strlen
    assert_equals conn_call($db, qw(strlen v4)), 6;

    # setnx
    assert_equals conn_call($db, qw(setnx v2 second)), 0;
    assert_equals conn_call($db, qw(setnx v6 sixth)), 1;
    assert_equals conn_call($db, qw(get v2)), 'two';
    assert_equals conn_call($db, qw(get v6)), 'sixth';

    # getrange
    assert_equals conn_call($db, qw(getrange v4 0 3)), 'four';
    assert_equals conn_call($db, qw(getrange v4 0 -3)), 'four';
    assert_equals conn_call($db, qw(getrange v4 -2 -1)), 'th';
};

# Integer commands: DECR, DECRBY, INCR, INCRBY
test 'self/02_db/int', sub {
    my $db = prepare(@_);

    assert_equals conn_call($db, qw(incr i)), 1;
    assert_equals conn_call($db, qw(incr i)), 2;
    assert_equals conn_call($db, qw(incrby i 9)), 11;
    assert_equals conn_call($db, qw(decrby i 5)), 6;
    assert_equals conn_call($db, qw(decr i)), 5;
};

# Hash commands: HDEL, HEXISTS, HGET, HGETALL, HINCRBY, HKEYS, HLEN, HMGET, HMSET, HSET
test 'self/02_db/hash', sub {
    my $db = prepare(@_);

    # Create hash
    conn_call($db, qw(hset hh f vf));
    conn_call($db, qw(hmset hh g vg h vh));

    # Check content
    assert_set_equals conn_call($db, qw(hkeys hh)), [qw(f g h)];
    assert_equals conn_call($db, qw(hexists hh e)), 0;
    assert_equals conn_call($db, qw(hexists hh f)), 1;
    assert_equals conn_call($db, qw(hget hh g)), 'vg';
    assert_equals conn_call($db, qw(hlen hh)), 3;
    assert_list_equals conn_call($db, qw(hmget hh f h)), [qw(vf vh)];

    # getall does not guarantee an oder
    my %v = conn_call_list($db, qw(hgetall hh));
    assert_equals $v{f}, 'vf';
    assert_equals $v{g}, 'vg';
    assert_equals $v{h}, 'vh';

    # Integer
    assert_equals conn_call($db, qw(hincrby hh a 1)), 1;
    assert_equals conn_call($db, qw(hincrby hh a 9)), 10;
    assert_equals conn_call($db, qw(hincrby hh a -5)), 5;
    assert_equals conn_call($db, qw(hget hh a)), 5;

    assert_equals conn_call($db, qw(hincrby qq a 0)), 0;
    assert_equals conn_call($db, qw(hget qq a)), 0;

    # Delete
    assert_equals conn_call($db, qw(hdel hh a)), 1;
    assert_equals conn_call($db, qw(hexists hh a)), 0;
    assert_equals conn_call($db, qw(hdel hh a)), 0;

    # Emptying a hash removes it
    assert_equals conn_call($db, qw(hdel qq a)), 1;
    assert_equals conn_call($db, qw(hexists qq a)), 0;
    assert_equals conn_call($db, qw(exists qq)), 0;
};


# List commands: LINDEX, LLEN, LPOP, LPUSH, LRANGE, LREM, LSET, LTRIM, RPOP, RPOPLPUSH, RPUSH
test 'self/02_db/list', sub {
    my $db = prepare(@_);

    # Build list
    foreach (qw(d e f)) {
        conn_call($db, qw(rpush list), $_);
    }
    foreach (qw(c b a)) {
        conn_call($db, qw(lpush list), $_);
    }
    foreach (qw(g h i)) {
        conn_call($db, qw(rpush list), $_);
    }

    # Check content
    assert_equals conn_call($db, qw(llen list)), 9;
    assert_equals conn_call($db, qw(lindex list 0)), 'a';
    assert_equals conn_call($db, qw(lindex list 1)), 'b';
    assert_equals conn_call($db, qw(lindex list 8)), 'i';
    assert_equals conn_call($db, qw(lindex list -2)), 'h';
    assert_list_equals conn_call($db, qw(lrange list 0 -1)), [qw(a b c d e f g h i)];
    assert_list_equals conn_call($db, qw(lrange list 0 2)),  [qw(a b c)];
    assert_list_equals conn_call($db, qw(lrange list -4 -2)),  [qw(f g h)];

    # Modify
    conn_call($db, qw(lset list 1 BB));
    conn_call($db, qw(lset list -2 HH));
    assert_list_equals conn_call($db, qw(lrange list 0 -1)), [qw(a BB c d e f g HH i)];

    assert_equals conn_call($db, qw(lrem list 1 d)), 1;
    assert_list_equals conn_call($db, qw(lrange list 0 -1)), [qw(a BB c e f g HH i)];

    assert_equals conn_call($db, qw(lpop list)), 'a';
    assert_equals conn_call($db, qw(rpop list)), 'i';
    assert_list_equals conn_call($db, qw(lrange list 0 -1)), [qw(BB c e f g HH)];

    # Move
    conn_call($db, qw(rpoplpush list other));
    assert_list_equals conn_call($db, qw(lrange list 0 -1)), [qw(BB c e f g)];
    assert_list_equals conn_call($db, qw(lrange other 0 -1)), [qw(HH)];
    
    # Trim
    conn_call($db, qw(ltrim list 2 3));
    assert_list_equals conn_call($db, qw(lrange list 0 -1)), [qw(e f)];
};

# Set commands: SADD, SCARD, , SISMEMBER, SMEMBERS, SMOVE, SPOP, SRANDMEMBER, SREM
test 'self/02_db/set', sub {
    my $db = prepare(@_);

    # Create
    foreach (qw(1 3 5 7 9)) {
        conn_call($db, qw(sadd a), $_);
    }
    foreach (qw(5 10 15 20)) {
        conn_call($db, qw(sadd b), $_);
    }

    # Query
    assert_equals conn_call($db, qw(scard a)), 5;
    assert_equals conn_call($db, qw(scard b)), 4;
    assert_equals conn_call($db, qw(sismember a 5)), 1;
    assert_equals conn_call($db, qw(sismember b 5)), 1;
    assert_equals conn_call($db, qw(sismember a 7)), 1;
    assert_equals conn_call($db, qw(sismember b 7)), 0;
    assert_set_equals conn_call($db, qw(smembers a)), [1,3,5,7,9];

    # Move
    assert_equals conn_call($db, qw(smove a b 1)), 1;
    assert_equals conn_call($db, qw(smove a b 5)), 1;
    assert_equals conn_call($db, qw(smove a b 6)), 0;
    assert_set_equals conn_call($db, qw(smembers a)), [3,7,9];
    assert_set_equals conn_call($db, qw(smembers b)), [1,5,10,15,20];

    # Random
    foreach (1 .. 100) {
        assert_equals conn_call($db, qw(srandmember a))%2, 1;
    }

    # Remove
    my $sum = 0;
    foreach (qw(7 9 11 13)) {
        $sum += conn_call($db, qw(srem a), $_);
    }
    assert_equals $sum, 2;

    # Pop - only one element remaining
    assert_equals conn_call($db, qw(spop a)), 3;
    assert_equals conn_call($db, qw(exists a)), 0;
};

# Set operation commands: SDIFF, SDIFFSTORE, SINTER, SINTERSTORE, SUNION, SUNIONSTORE
test 'self/02_db/setop', sub {
    my $db = prepare(@_);

    # Setup
    foreach (qw(1 3 5 7 9)) {
        conn_call($db, qw(sadd a), $_);
    }
    foreach (qw(1 2 3 4 5)) {
        conn_call($db, qw(sadd b), $_);
    }

    # Verify single
    assert_set_equals conn_call($db, qw(sdiff a b)), [7,9];
    assert_set_equals conn_call($db, qw(sdiff b a)), [2,4];
    assert_set_equals conn_call($db, qw(sinter a b)), [1,3,5];
    assert_set_equals conn_call($db, qw(sinter b a)), [1,3,5];
    assert_set_equals conn_call($db, qw(sunion a b)), [1,2,3,4,5,7,9];
    assert_set_equals conn_call($db, qw(sunion b a)), [1,2,3,4,5,7,9];

    # Verify assignments
    conn_call($db, qw(sdiffstore diff a b));
    conn_call($db, qw(sinterstore inter a b));
    conn_call($db, qw(sunionstore union a b));
    assert_set_equals conn_call($db, qw(smembers diff)), [7,9];
    assert_set_equals conn_call($db, qw(smembers inter)), [1,3,5];
    assert_set_equals conn_call($db, qw(smembers union)), [1,2,3,4,5,7,9];
};

# Sort
test 'self/02_db/sort', sub {
    my $db = prepare(@_);

    # Setup
    foreach (qw(1 3 5 7 9 11)) {
        conn_call($db, qw(sadd a), $_);
    }

    # Simple test
    assert_list_equals conn_call($db, qw(sort a)), [1,3,5,7,9,11];
    assert_list_equals conn_call($db, qw(sort a alpha)), [1,11,3,5,7,9];

    # Foreign keys
    conn_call($db, qw(mset k1 one k3 three k5 five k7 seven k9 nine k11 eleven));
    assert_set_equals conn_call($db, qw(sort a by k* alpha)), [qw(11 5 9 1 7 3)];
    assert_set_equals conn_call($db, qw(sort a by k* alpha get k*)), [qw(eleven five nine one seven three)];
    assert_set_equals conn_call($db, qw(sort a by k* alpha get), '#', qw(get k*)), [qw(11 eleven 5 five 9 nine 1 one 7 seven 3 three)];

    assert_set_equals conn_call($db, qw(sort a get k*)), [qw(one three five seven nine eleven)];
    assert_set_equals conn_call($db, qw(sort a get k* desc)), [qw(eleven nine seven five three one)];
};

# Implicit deletion
test 'self/02_db/delete', sub {
    my $db = prepare(@_);

    # String does NOT disappear
    conn_call($db, qw(set k v));
    assert_equals conn_call($db, qw(type k)), 'string';
    assert_equals conn_call($db, qw(exists k)), 1;
    conn_call($db, qw(set k), '');
    assert_equals conn_call($db, qw(exists k)), 1;      # remains!

    # List does disappear
    conn_call($db, qw(rpush l v));
    assert_equals conn_call($db, qw(type l)), 'list';
    assert_equals conn_call($db, qw(exists l)), 1;
    assert_equals conn_call($db, qw(rpop l)), 'v';
    assert_equals conn_call($db, qw(exists l)), 0;

    # Set does disappear
    conn_call($db, qw(sadd s v));
    assert_equals conn_call($db, qw(type s)), 'set';
    assert_equals conn_call($db, qw(exists s)), 1;
    assert_equals conn_call($db, qw(srem s v)), 1;
    assert_equals conn_call($db, qw(exists s)), 0;

    # Hash does disappear
    conn_call($db, qw(hset h k v));
    assert_equals conn_call($db, qw(type h)), 'hash';
    assert_equals conn_call($db, qw(exists h)), 1;
    assert_equals conn_call($db, qw(hdel h k)), 1;
    assert_equals conn_call($db, qw(exists h)), 0;

    # Final check
    assert_set_equals conn_call($db, qw(keys *)), ['k'];
};

sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_start_wait($setup);
    return setup_connect_app($setup, 'db');
}

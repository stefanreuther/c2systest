#!/usr/bin/perl -w
#
#  Host: HostTool
#
#  Synced with TestServerHostHostTool, 20170925
#
use strict;
use c2systest;

# TestServerHostHostTool::testBasic: basic operations
test 'host/50_tool/basic', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Create a tool that does not need a file
    conn_call($hc, 'tooladd', 'tool-id', '', '', 'toolkind');
    conn_call($hc, 'toolset', 'tool-id', 'description', 'Lengthy text...');
    assert_equals conn_call($hc, 'toolget', 'tool-id', 'description'), 'Lengthy text...';

    # Try to create a tool that needs a file.
    # This fails because the file does not exist.
    assert_throws sub{ conn_call($hc, 'tooladd', 'tool-file', 'dir', 'file', 'toolkind') }, 412;

    # OK, create the file and try again.
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(mkdir dir));
    conn_call($hfc, qw(put dir/file content));
    conn_call($hc, 'tooladd', 'tool-file', 'dir', 'file', 'toolkind');
};

# TestServerHostHostTool::testList:* Test list operations
test 'host/50_tool/list', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Create some tools
    conn_call($hc, 'masteradd', 'a', '', '', 'ak');
    conn_call($hc, 'masteradd', 'b', '', '', 'bk');
    conn_call($hc, 'masteradd', 'c', '', '', 'ck');

    # Fetch
    my @list = sort {$a->{id} cmp $b->{id}} conn_call_list_of_hash($hc, 'masterls');
    assert_equals scalar(@list), 3;
    assert_equals $list[0]{id}, 'a';
    assert_equals $list[0]{kind}, 'ak';
    assert_equals $list[0]{default}, 1;
    assert_equals $list[1]{id}, 'b';
    assert_equals $list[1]{kind}, 'bk';
    assert_equals $list[1]{default}, 0;
    assert_equals $list[2]{id}, 'c';
    assert_equals $list[2]{kind}, 'ck';
    assert_equals $list[2]{default}, 0;

    # Make one default
    conn_call($hc, 'masterdefault', 'c');
    @list = sort {$a->{id} cmp $b->{id}} conn_call_list_of_hash($hc, 'masterls');
    assert_equals $list[0]{default}, 0;
    assert_equals $list[1]{default}, 0;
    assert_equals $list[2]{default}, 1;

    # Remove c
    conn_call($hc, 'masterrm', 'c');
    @list = sort {$a->{id} cmp $b->{id}} conn_call_list_of_hash($hc, 'masterls');
    assert_equals scalar(@list), 2;
    assert_equals $list[0]{id}, 'a';
    assert_equals $list[1]{id}, 'b';
    assert $list[0]{default} || $list[1]{default};
};


# TestServerHostHostTool::testCopy: xxCP
test 'host/50_tool/cp', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Create a tool
    conn_call($hc, 'hostadd', 'a', '', '', 'kk');
    conn_call($hc, 'hostset', 'a', 'description', 'Lengthy text...');
    conn_call($hc, 'hostset', 'a', 'docurl', 'http://');

    # Copy
    conn_call($hc, 'hostcp', 'a', 'x');

    # Verify
    my @list = sort {$a->{id} cmp $b->{id}} conn_call_list_of_hash($hc, 'hostls');
    assert_equals scalar(@list), 2;
    assert_equals $list[0]{id}, 'a';
    assert_equals $list[0]{default}, 1;
    assert_equals $list[1]{id}, 'x';
    assert_equals $list[1]{default}, 0;

    assert_equals conn_call($hc, 'hostget', 'x', 'docurl'), 'http://';
};

# TestServerHostHostTool::testErrors: error cases
test 'host/50_tool/errors', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'hostadd', 'x', '', '', 'k');

    # Bad Id
    assert_throws sub{ conn_call($hc, 'hostadd', '', '', '', 'k') }, 412;
    assert_throws sub{ conn_call($hc, 'hostadd', 'a b', '', '', 'k') }, 412;
    assert_throws sub{ conn_call($hc, 'hostadd', "a\xC3\xB6", '', '', 'k') }, 412;
    assert_throws sub{ conn_call($hc, 'hostset', '', 'k', 'v') }, 412;
    assert_throws sub{ conn_call($hc, 'hostcp', 'x', '') }, 412;

    # Bad Kind
    assert_throws sub{ conn_call($hc, 'hostadd', 'a', '', '', '') }, 412;
    assert_throws sub{ conn_call($hc, 'hostadd', 'a', '', '', 'a b') }, 412;
    assert_throws sub{ conn_call($hc, 'hostadd', 'a', '', '', 'a-b') }, 412;

    # Nonexistant
    assert_throws sub{ conn_call($hc, 'hostcp', 'a', 'b') }, 404;
    assert_throws sub{ conn_call($hc, 'hostdefault', 'a') }, 404;
    assert_throws sub{ conn_call($hc, 'hostrating', 'a', 'get') }, 404;
    assert_throws sub{ conn_call($hc, 'hostrating', 'a', 'none') }, 404;
    assert_throws sub{ conn_call($hc, 'hostrating', 'a', 'set', 99, 'use') }, 404;

    # Missing tool
    assert_throws sub{ conn_call($hc, 'hostadd', 'a', 'b', 'c', 'd') }, 412;
};

# TestServerHostHostTool::testDifficulty: Test difficulty access commands.
test 'host/50_tool/rating', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Add a tool
    conn_call($hc, 'hostadd', 't', '', '', 'k');
    assert_equals conn_call($hc, qw(hostrating t get)), 0;

    # Set difficulty
    conn_call($hc, qw(hostrating t set 33 use));
    assert_equals conn_call($hc, qw(hostrating t get)), 33;

    # Remove difficulty
    conn_call($hc, qw(hostrating t none));
    assert_equals conn_call($hc, qw(hostrating t get)), 0;
};

# TestServerHostHostTool::testComputedDifficulty: Test difficulty computation.
test 'host/50_tool/computed', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');

    # Upload a config file for an ultra-rich game
    conn_call($hfc, qw(mkdir dir));
    conn_call($hfc, qw(put dir/amaster.src),
              "%amaster\n".
              "planetcorerangesalternate=10000,20000\n".
              "planetcorerangesusual=10000,20000\n".
              "planetcoreusualfrequency=50\n".
              "planetsurfaceranges=5000,10000\n");

    # Add as tool
    conn_call($hc, 'hostadd', 'easy', 'dir', '', 'config');

    # Compute difficulty
    assert_equals conn_call($hc, qw(hostrating easy auto use)), 28;
    assert_equals conn_call($hc, qw(hostrating easy get)),      28;

    # Change the file to make it harder
    conn_call($hfc, qw(put dir/amaster.src),
              "%amaster\n".
              "planetcorerangesalternate=100,200\n".
              "planetcorerangesusual=100,200\n".
              "planetcoreusualfrequency=50\n".
              "planetsurfaceranges=50,100\n");
    assert_equals conn_call($hc, qw(hostrating easy auto use)), 126;
    assert_equals conn_call($hc, qw(hostrating easy get)),      126;
};

sub prepare {
    my $setup = shift;
    setup_add_host($setup, '-nocron');
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
}

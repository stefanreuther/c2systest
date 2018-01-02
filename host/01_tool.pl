#!/usr/bin/perl -w
#
#  Host: test for tool management commands
#
use strict;
use c2systest;

# General tests for tools.
test 'host/01_tool/general', sub {
    my $setup = shift;
    my ($hc, $hfc) = prepare_for_tools($setup);

    # Add a few hosts
    # This is the installation routine (upload_phost4.con), replicated twice.
    # It will produce two hosts (N1, N2) and a default entry (NC);
    # the latter is created twice and thus exercises overwriting.
    conn_call($hfc, qw(mkdirhier tools/N1));
    conn_call($hfc, qw(put tools/N1/phost exe));
    conn_call($hc, qw(hostadd N1 tools/N1 phost phost4));
    conn_call($hc, qw(hostset N1 description Description_for_N1));
    conn_call($hc, qw(hostset N1 mainurl http://phost.de/));
    conn_call($hc, qw(hostset N1 docurl http://phost.de/docs.html));
    conn_call($hc, qw(hostset N1 extradescription Extra_for_N1));
    conn_call($hc, qw(hostrating N1 none));
    conn_call($hc, qw(hostcp N1 NC));
    conn_call($hc, qw(hostset NC description Description_for_C));
    conn_call($hc, qw(hostset NC extradescription Extra_for_C_1));
    conn_call($hc, qw(hostdefault NC));

    conn_call($hfc, qw(mkdirhier tools/N2));
    conn_call($hfc, qw(put tools/N2/phost exe));
    conn_call($hc, qw(hostadd N2 tools/N2 phost phost4));
    conn_call($hc, qw(hostset N2 description Description_for_N2));
    conn_call($hc, qw(hostset N2 mainurl http://phost.de/));
    conn_call($hc, qw(hostset N2 docurl http://phost.de/docs.html));
    conn_call($hc, qw(hostset N2 extradescription Extra_for_N2));
    conn_call($hc, qw(hostrating N2 none));
    conn_call($hc, qw(hostcp N2 NC));
    conn_call($hc, qw(hostset NC description Description_for_C));
    conn_call($hc, qw(hostset NC extradescription Extra_for_C_2));
    conn_call($hc, qw(hostdefault NC));

    # Interrogate and check
    assert_equals(conn_call($hc, qw(hostget N1 extradescription)), "Extra_for_N1");
    assert_equals(conn_call($hc, qw(hostget N2 extradescription)), "Extra_for_N2");
    assert_equals(conn_call($hc, qw(hostget NC extradescription)), "Extra_for_C_2");
    assert_equals(conn_call($hc, qw(hostget NC path)), "tools/N2");
    assert_equals(conn_call($hc, qw(hostget NC difficulty)), '');
    assert_equals(conn_call($hc, qw(hostget NC useDifficulty)), '');

    my @list = sort {$a->{id} cmp $b->{id}} map {{@$_}} @{ conn_call($hc, 'hostls') };
    assert_num_equals(scalar(@list), 3);

    assert_equals($list[0]{id}, "N1");
    assert_equals($list[1]{id}, "N2");
    assert_equals($list[2]{id}, "NC");
    assert_num_equals($list[0]{default}, 0);
    assert_num_equals($list[1]{default}, 0);
    assert_num_equals($list[2]{default}, 1);

    # Verify database representation
    my $dbc = setup_connect_app($setup, 'db');
    assert_equals conn_call($dbc, qw(hget prog:host:prog:N2 description)), "Description_for_N2";
    assert_equals conn_call($dbc, qw(hget prog:host:prog:N2 mainurl)), "http://phost.de/";
    assert_equals conn_call($dbc, qw(hget prog:host:prog:N2 path)), "tools/N2";
    assert_equals conn_call($dbc, qw(hget prog:host:prog:NC path)), "tools/N2";
    assert_equals conn_call($dbc, qw(sismember prog:host:list N1)), 1;
    assert_equals conn_call($dbc, qw(sismember prog:host:list N2)), 1;
    assert_equals conn_call($dbc, qw(sismember prog:host:list NC)), 1;
    assert_equals conn_call($dbc, qw(scard prog:host:list)), 3;
    assert_equals conn_call($dbc, qw(get prog:host:default)), 'NC';
};

# Test rating commands.
test 'host/01_tool/rating', sub {
    my $setup = shift;
    my ($hc, $hfc) = prepare_for_tools($setup);
    conn_call($hfc, qw(mkdirhier sldir));
    conn_call($hfc, qw(put sldir/x x));
    conn_call($hc, qw(shiplistadd S1 sldir x y));

    # Default value (not set): 0
    assert_num_equals(conn_call($hc, qw(shiplistrating S1 get)), 0);

    # "auto show" sets the value to the computed value for display only
    assert_num_equals(conn_call($hc, qw(shiplistrating S1 auto show)), 100);
    assert_num_equals(conn_call($hc, qw(shiplistrating S1 get)), 100);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 difficulty)), 100);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 useDifficulty)), 0);

    # "auto use" sets the value to the computed value and would also use it in computing game difficulty
    conn_call($hc, qw(shiplistrating S1 auto use));
    assert_num_equals(conn_call($hc, qw(shiplistrating S1 get)), 100);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 difficulty)), 100);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 useDifficulty)), 1);

    # "set N show" sets the value to the given value for display only
    conn_call($hc, qw(shiplistrating S1 set 42 show));
    assert_num_equals(conn_call($hc, qw(shiplistrating S1 get)), 42);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 difficulty)), 42);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 useDifficulty)), 0);

    # "set N use" sets the value to the given value and would also use it in computing game difficulty
    conn_call($hc, qw(shiplistrating S1 set 77 use));
    assert_num_equals(conn_call($hc, qw(shiplistrating S1 get)), 77);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 difficulty)), 77);
    assert_num_equals(conn_call($hc, qw(shiplistget S1 useDifficulty)), 1);
};

# Test rating commands, take 2.
test 'host/01_tool/rating2', sub {
    my $setup = shift;
    my ($hc, $hfc) = prepare_for_tools($setup);

    # Upload PHost
    conn_call($hfc, qw(mkdir phdir));
    conn_call($hfc, qw(put phdir/phost), file_content(setup_get_required_system_config($setup, 'programs').'/phost-4.1h/phost'));
    conn_call($hfc, qw(put phdir/pconfig.src), file_content(setup_get_required_system_config($setup, 'programs').'/phost-4.1h/config/simple.src'));

    # Add to Host
    conn_call($hc, qw(hostadd phost41h phdir phost phost));

    # Verify actual difficulty computation
    assert_num_equals(conn_call($hc, qw(hostrating phost41h auto show)), 98);
};

# Test rating commands, take 3 [same as TestServerHostHostTool::testComputedDifficulty]
test 'host/01_tool/rating3', sub {
    my $setup = shift;
    my ($hc, $hfc) = prepare_for_tools($setup);

    # Upload a config file for an ultra-rich game
    conn_call($hfc, 'mkdir', 'dir');
    conn_call($hfc, 'put', 'dir/amaster.src',
              "%amaster\n".
              "planetcorerangesalternate=10000,20000\n".
              "planetcorerangesusual=10000,20000\n".
              "planetcoreusualfrequency=50\n".
              "planetsurfaceranges=5000,10000\n");

    # Add as tool
    conn_call($hc, 'tooladd', 'easy', 'dir', '', 'config');

    # Compute difficulty
    assert_num_equals conn_call($hc, qw(toolrating easy auto use)), 28;
    assert_num_equals conn_call($hc, qw(toolrating easy get)),      28;

    # Change the file to make it harder
    conn_call($hfc, 'put', 'dir/amaster.src',
              "%amaster\n".
              "planetcorerangesalternate=100,200\n".
              "planetcorerangesusual=100,200\n".
              "planetcoreusualfrequency=50\n".
              "planetsurfaceranges=50,100\n");
    assert_num_equals conn_call($hc, qw(toolrating easy auto use)), 126;
    assert_num_equals conn_call($hc, qw(toolrating easy get)),      126;
};


sub prepare_for_tools {
    my $setup = shift;
    my $hs = setup_add_host($setup);
    my $hfs = setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = service_connect($hs);
    my $hfc = service_connect($hfs);
    ($hc, $hfc);
}

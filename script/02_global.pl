#!/usr/bin/perl -w
#
#  Script: global properties
#
use strict;
use c2systest;
use c2script;

# FIXME: System.Local
# FIXME: System.Remote
# FIXME: System.GameDirectory
# FIXME: System.RootDirectory
# FIXME: Selection.Layer
# FIXME: System.Language
# FIXME: System.RandomSeed

# Test My.InMsgs, My.OutMsgs, My.VCRs
test 'script/02_global/messages', sub {
    my $setup = shift;

    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print my.inmsgs'), "20\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print my.outmsgs'), "0\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print my.vcrs'), "0\n";
};

# Test System.Program, System.Veersion, System.Version$
test 'script/02_global/id', sub {
    my $setup = shift;

    assert_equals      c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.program'),  "PCC\n";
    assert_starts_with c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.version'),  "2.";
    assert_num_greater c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.version$'), "240000";
};

# Test System.Host, System.Host$, System.HostVersion
test 'script/02_global/host', sub {
    my $setup = shift;

    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.host'),        "PHost\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.host$'),       "2\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.hostversion'), "401008\n";
};

# Test System.GameType$, System.GameType, System.RegStr1, System.RegStr2
test 'script/02_global/reg', sub {
    my $setup = shift;

    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.gametype'),  "Shareware\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.gametype$'), "YES\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.regstr1'), "VGA Planets shareware\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print system.regstr2'), "PCC II\n";
};

# Test Turn, Turn.IsNew, Turn.Time, Turn.Date
test 'script/02_global/turn', sub {
    my $setup = shift;

    assert_equals c2script::setup_call_script_on_game($setup, 'data/game',  'print turn'), "131\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game',  'print turn.isnew'), "YES\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game',  'print turn.time'), "22:46:01\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game',  'print turn.date'), "06-01-2012\n";

    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print turn'), "27\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print turn.isnew'), "YES\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print turn.time'), "12:00:03\n";
    assert_equals c2script::setup_call_script_on_game($setup, 'data/game2', 'print turn.date'), "07-09-2017\n";
};

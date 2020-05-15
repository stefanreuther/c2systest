#!/usr/bin/perl -w
#
#  c2play-server: ship properties
#
use strict;
use c2systest;

# Test retrieving own ship.
# A: GET a ship
# E: verify properties are as expected
test 'play/05_ship/get43', sub {
    my $setup = shift;
    my $data = call_str($setup, "GET obj/ship93");

    assert $data->{ship93};

    my $p = $data->{ship93};
    assert_equals $p->{AUX}, 9;         # Mk7
    assert_equals $p->{'AUX.AMMO'}, 0;
    assert_equals $p->{'AUX.COUNT'}, 2;
    assert_equals $p->{BEAM}, 7;
    assert_equals $p->{'BEAM.COUNT'}, 4;
    assert $p->{CARGO};
    assert_equals $p->{CARGO}{COLONISTS}, 0;
    assert_equals $p->{CARGO}{D}, 89;
    assert_equals $p->{CARGO}{M}, 177;
    assert_equals $p->{CARGO}{MC}, 0;
    assert_equals $p->{CARGO}{N}, 113;
    assert_equals $p->{CARGO}{SUPPLIES}, 6;
    assert_equals $p->{CARGO}{T}, 98;
    assert_equals $p->{CREW}, 136;
    assert_equals $p->{DAMAGE}, 0;
    assert_equals $p->{ENEMY}, 0;
    assert_equals $p->{ENGINE}, 9;
    assert_equals $p->{FCODE}, 'P^"';
    assert_equals $p->{HEADING}, 90;
    assert_equals $p->{HULL}, 60;
    assert_equals $p->{MISSION}, 5;
    assert_equals $p->{'MISSION.INTERCEPT'}, 0;
    assert_equals $p->{'MISSION.TOW'}, 0;
    assert_equals $p->{'MOVE.ETA'}, 1;
    assert_equals $p->{'MOVE.FUEL'}, 1;
    assert_equals $p->{'OWNER.REAL'}, 7;
    assert_equals $p->{SPEED}, 9;
    assert_equals $p->{'WAYPOINT.DX'}, 3;
    assert_equals $p->{'WAYPOINT.DY'}, 0;
};

# Test retrieving foreign ship.
# A: GET a foreign ship
# E: verify properties are as expected
test 'play/05_ship/get9', sub {
    my $setup = shift;
    my $data = call_str($setup, "GET obj/ship9");

    assert $data->{ship9};

    my $p = $data->{ship9};
    assert_equals $p->{HULL}, 16;
    assert_equals $p->{'OWNER.REAL'}, 11;
    assert_equals $p->{SPEED}, 7;
};

# The following tests all test a single successful command each.

test 'play/05_ship/setcomment', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship93', '[["setcomment", "narf"]]', '.');
    assert $data->{ship93};
    assert_equals $data->{ship93}{COMMENT}, "narf";
};

test 'play/05_ship/setfcode', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship93', '[["setfcode", "foo"]]', '.');
    assert $data->{ship93};
    assert_equals $data->{ship93}{FCODE}, "foo";
};

test 'play/05_ship/setname', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship93', '[["setname", "Black Pearl"]]', '.');

    # SetName affects shipxy, not shipX
    assert $data->{shipxy};
    assert_equals $data->{shipxy}[93]{NAME}, "Black Pearl";
};

test 'play/05_ship/setwaypoint', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship93', '[["setwaypoint", 2200, 2800]]', '.');
    assert $data->{ship93};
    assert_equals $data->{ship93}{'WAYPOINT.DX'}, -81;
    assert_equals $data->{ship93}{'WAYPOINT.DY'}, -71;
};

test 'play/05_ship/setenemy', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship93', '[["setenemy", 9]]', '.');
    assert $data->{ship93};
    assert_equals $data->{ship93}{ENEMY}, 9;
};

test 'play/05_ship/setspeed', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship93', '[["setspeed", 2]]', '.');
    assert $data->{ship93};
    assert_equals $data->{ship93}{SPEED}, 2;
};

test 'play/05_ship/setmission', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship93', '[["setmission", 8, 34]]', '.');
    assert $data->{ship93};
    assert_equals $data->{ship93}{MISSION}, 8;
    assert_equals $data->{ship93}{'MISSION.INTERCEPT'}, 34;
    assert_equals $data->{ship93}{'MISSION.TOW'}, 0;
    assert_equals $data->{ship93}{'WAYPOINT.DX'}, -37;
    assert_equals $data->{ship93}{'WAYPOINT.DY'}, -31;
};

test 'play/05_ship/cargotransfer', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship158', '[["cargotransfer", "10n 35d", 235]]', '.');

    assert $data->{ship158};
    assert_equals $data->{ship158}{CARGO}{N}, 29;
    assert_equals $data->{ship158}{CARGO}{D}, 136;

    assert $data->{ship235};
    assert_equals $data->{ship235}{CARGO}{N}, 31;
    assert_equals $data->{ship235}{CARGO}{D}, 113;
};

test 'play/05_ship/cargoupload', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship308', '[["cargoupload", "15mt"]]', '.');

    assert $data->{ship308};
    assert_equals $data->{ship308}{CARGO}{N}, 82;
    assert_equals $data->{ship308}{CARGO}{T}, 57;
    assert_equals $data->{ship308}{CARGO}{D}, 35;
    assert_equals $data->{ship308}{CARGO}{M}, 78;

    assert $data->{planet14};
    assert_equals $data->{planet14}{G}{N}, 144;
    assert_equals $data->{planet14}{G}{T}, 135;
    assert_equals $data->{planet14}{G}{D}, 32;
    assert_equals $data->{planet14}{G}{M}, 45;
};

test 'play/05_ship/cargounload', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/ship308', '[["cargounload", "17d -5n"]]', '.');
    
    assert $data->{ship308};
    assert_equals $data->{ship308}{CARGO}{N}, 87;
    assert_equals $data->{ship308}{CARGO}{T}, 42;
    assert_equals $data->{ship308}{CARGO}{D}, 18;
    assert_equals $data->{ship308}{CARGO}{M}, 63;

    assert $data->{planet14};
    assert_equals $data->{planet14}{G}{N}, 139;
    assert_equals $data->{planet14}{G}{T}, 150;
    assert_equals $data->{planet14}{G}{D}, 49;
    assert_equals $data->{planet14}{G}{M}, 60;
};


# call_str($setup, @args): Call single command consisting of lines given in @args (function adds newline separatorss);
# expect success response. Return parsed data.
sub call_str {
    my $setup = shift;
    my $str = join("\n", @_)."\n";
    my $dir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $dir, 0777 or die "$dir: $!";
    file_put("$dir/player7.rst", file_content("data/game2/player7.rst"));

    my $shell = shell_new($setup, 'server');
    shell_add_args($shell, $dir, 7);
    my @out = split /\n/, shell_call($shell, $str);
    assert_starts_with shift(@out), '100';
    assert_starts_with shift(@out), '200';
    assert_equals pop(@out), '.';

    return json_parse(join("\n", @out));
}

#!/usr/bin/perl -w
#
#  c2play-server: planet properties
#
use strict;
use c2systest;

# Test retrieving planet with natives.
# A: GET a planet
# E: verify properties are as expected
test 'play/04_planet/get43', sub {
    my $setup = shift;
    my $data = call_str($setup, "GET obj/planet43");

    assert $data->{planet43};

    my $p = $data->{planet43};
    assert $p->{G};
    assert_equals $p->{G}{COLONISTS}, 280;
    assert_equals $p->{'COLONISTS.HAPPY'}, 100;
    assert_equals $p->{'COLONISTS.SUPPORTED'},  48000;
    assert_equals $p->{'COLONISTS.TAX'}, 0;
    assert_equals $p->{DEFENSE}, 39;
    assert_equals $p->{'DEFENSE.BASE.WANT'}, 20;
    assert_equals $p->{'DEFENSE.WANT'}, 1000;
    assert_equals $p->{'DENSITY.D'}, 59;
    assert_equals $p->{'DENSITY.M'}, 24;
    assert_equals $p->{'DENSITY.N'}, 45;
    assert_equals $p->{'DENSITY.T'}, 57;
    assert_equals $p->{'FACTORIES'}, 101;
    assert_equals $p->{'FACTORIES.WANT'}, 1000;
    assert_equals $p->{'FCODE'}, 'nx+';
    assert_equals $p->{'GROUND.D'}, 529;
    assert_equals $p->{'GROUND.M'}, 149;
    assert_equals $p->{'GROUND.N'}, 576;
    assert_equals $p->{'GROUND.T'}, 832;
    assert_equals $p->{'INDUSTRY'}, 4;
    assert_equals $p->{G}{D}, 33;
    assert_equals $p->{G}{M}, 14;
    assert_equals $p->{G}{N}, 52;
    assert_equals $p->{G}{T}, 32;
    assert_equals $p->{MINES}, 33;
    assert_equals $p->{'MINES.WANT'}, 1000;
    assert !$p->{'MISSION'};
    assert_equals $p->{G}{MC}, 19;
    assert_equals $p->{NATIVES}, 11094;
    assert_equals $p->{'NATIVES.GOV'}, 9;
    assert_equals $p->{'NATIVES.HAPPY'}, 71;
    assert_equals $p->{'NATIVES.RACE'}, 2;
    assert_equals $p->{'NATIVES.TAX'}, 1;
    assert_equals $p->{G}{SUPPLIES}, 209;
    assert_equals $p->{TEMP}, 48;
};

# Test retrieving planet with base.
# A: GET a planet
# E: verify properties are as expected
test 'play/04_planet/get63', sub {
    my $setup = shift;
    my $data = call_str($setup, "GET obj/planet63");

    assert $data->{planet63};

    my $p = $data->{planet63};
    assert !$p->{BUILD};                 # Not building a ship
    assert $p->{G};
    assert_equals $p->{G}{COLONISTS}, 52266;
    assert_equals $p->{'COLONISTS.HAPPY'}, 85;
    assert_equals $p->{'COLONISTS.SUPPORTED'}, 100000;
    assert_equals $p->{'COLONISTS.TAX'}, 14;
    assert_equals $p->{DAMAGE}, 0;
    assert_equals $p->{DEFENSE}, 100;
    assert_equals $p->{'DEFENSE.BASE'}, 10;
    assert_equals $p->{'DEFENSE.BASE.WANT'}, 20;
    assert_equals $p->{'DEFENSE.WANT'}, 1000;
    assert_equals $p->{'DENSITY.D'}, 15;
    assert_equals $p->{'DENSITY.M'}, 95;
    assert_equals $p->{'DENSITY.N'}, 20;
    assert_equals $p->{'DENSITY.T'}, 20;
    assert_equals $p->{'FACTORIES'}, 326;
    assert_equals $p->{'FACTORIES.WANT'}, 1000;
    assert_equals $p->{'FCODE'}, ',Fv';
    assert_equals $p->{'FIGHTERS'}, 20;
    assert_equals $p->{'GROUND.D'}, 2825;
    assert_equals $p->{'GROUND.M'}, 5;
    assert_equals $p->{'GROUND.N'}, 8832;
    assert_equals $p->{'GROUND.T'}, 901;
    assert_equals $p->{'INDUSTRY'}, 4;
    assert_equals $p->{G}{D}, 48;
    assert_equals $p->{G}{M}, 25;
    assert_equals $p->{G}{N}, 1212;
    assert_equals $p->{G}{T}, 1648;
    assert_equals $p->{MINES}, 290;
    assert_equals $p->{'MINES.WANT'}, 1000;
    assert_equals $p->{'MISSION'}, 6;
    assert_equals $p->{G}{MC}, 722;
    assert_equals $p->{NATIVES}, 0;
    assert_equals $p->{'NATIVES.RACE'}, 0;
    assert_equals $p->{'SHIPYARD.ID'}, 0;
    assert_equals $p->{'STORAGE.AMMO'}[0], 0;  # dummy
    assert_equals $p->{'STORAGE.AMMO'}[1], 0;  # Mk1
    assert_equals $p->{'STORAGE.AMMO'}[2], 20; # Proton
    assert_equals $p->{'STORAGE.AMMO'}[3], 0;  # Mk2
    assert_equals $p->{'STORAGE.AMMO'}[7], 14; # Mk5
    assert_equals $p->{'STORAGE.AMMO'}[10], 0; # Mk8
    assert_equals $p->{'STORAGE.AMMO'}[11], 20; # fighters
    assert $p->{'STORAGE.BEAMS'};
    assert $p->{'STORAGE.ENGINES'};
    assert $p->{'STORAGE.HULLS'};
    assert $p->{'STORAGE.LAUNCHERS'};
    assert_equals $p->{G}{SUPPLIES}, 608;
    assert_equals $p->{'TECH.BEAM'}, 8;
    assert_equals $p->{'TECH.ENGINE'}, 10;
    assert_equals $p->{'TECH.HULL'}, 10;
    assert_equals $p->{'TECH.TORPEDO'}, 10;
    assert_equals $p->{TEMP}, 100;
};

# The following tests all test a single successful command each.

test 'play/04_planet/setcomment', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet3', '[["setcomment","hi mom"]]', '.');
    assert $data->{planet3};
    assert_equals $data->{planet3}{COMMENT}, 'hi mom';
};

test 'play/04_planet/setfcode', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet43', '[["setfcode","abc"]]', '.');
    assert $data->{planet43};
    assert_equals $data->{planet43}{FCODE}, 'abc';
};

test 'play/04_planet/fixship', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet63', '[["fixship",235]]', '.');
    assert $data->{planet63};
    assert_equals $data->{planet63}{'SHIPYARD.ACTION'}, 'Fix';
    assert_equals $data->{planet63}{'SHIPYARD.ID'}, 235;
    # FIXME: response should contain ship 235
};

test 'play/04_planet/recycleship', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet63', '[["recycleship",315]]', '.');
    assert $data->{planet63};
    assert_equals $data->{planet63}{'SHIPYARD.ACTION'}, 'Recycle';
    assert_equals $data->{planet63}{'SHIPYARD.ID'}, 315;
};

test 'play/04_planet/buildbase', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet187', '[["buildbase"]]', '.');
    assert $data->{planet187};
    assert_equals $data->{planet187}{'BASE.BUILDING'}, 1;
    assert_equals $data->{planet187}{G}{MC}, 0;
    assert_equals $data->{planet187}{G}{SUPPLIES}, 273;
};

test 'play/04_planet/autobuild', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet187', '[["autobuild"]]', '.');
    assert $data->{planet187};
    assert_equals $data->{planet187}{MINES}, 217;
    assert_equals $data->{planet187}{FACTORIES}, 120;
    assert_equals $data->{planet187}{DEFENSE}, 71;
    assert_equals $data->{planet187}{G}{MC}, 66;
    assert_equals $data->{planet187}{G}{SUPPLIES}, 318;
};

test 'play/04_planet/builddefense', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet241', '[["builddefense",5]]', '.');
    assert $data->{planet241};
    assert_equals $data->{planet241}{DEFENSE}, 41;
    assert_equals $data->{planet241}{G}{MC}, 2;
    assert_equals $data->{planet241}{G}{SUPPLIES}, 47;
};

test 'play/04_planet/buildfactories', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet23', '[["buildfactories",7]]', '.');
    assert $data->{planet23};
    assert_equals $data->{planet23}{FACTORIES}, 39;
    assert_equals $data->{planet23}{G}{MC}, 0;
    assert_equals $data->{planet23}{G}{SUPPLIES}, 7;
};

test 'play/04_planet/buildmines', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet14', '[["buildmines",3]]', '.');
    assert $data->{planet14};
    assert_equals $data->{planet14}{MINES}, 53;
    assert_equals $data->{planet14}{G}{MC}, 342;
    assert_equals $data->{planet14}{G}{SUPPLIES}, 214;
};

test 'play/04_planet/buildbasedefense', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet63', '[["buildbasedefense",15]]', '.');
    assert $data->{planet63};
    assert_equals $data->{planet63}{'DEFENSE.BASE'}, 25;
    assert_equals $data->{planet63}{G}{MC}, 572;
    assert_equals $data->{planet63}{G}{SUPPLIES}, 608;
    assert_equals $data->{planet63}{G}{D}, 33;
};

test 'play/04_planet/setcolonisttax', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet63', '[["setcolonisttax",3]]', '.');
    assert $data->{planet63};
    assert_equals $data->{planet63}{'COLONISTS.TAX'}, 3;
};

test 'play/04_planet/setnativetax', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet103', '[["setnativetax",5]]', '.');
    assert $data->{planet103};
    assert_equals $data->{planet103}{'NATIVES.TAX'}, 5;
};

test 'play/04_planet/setmission', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet140', '[["setmission",2]]', '.');
    assert $data->{planet140};
    assert_equals $data->{planet140}{MISSION}, 2;
};

test 'play/04_planet/settech', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet140', '[["settech",1,2]]', '.');
    assert $data->{planet140};
    assert_equals $data->{planet140}{'TECH.ENGINE'}, 2;
    assert_equals $data->{planet140}{G}{MC}, 74;
};

test 'play/04_planet/buildfighters', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet140', '[["buildfighters",2]]', '.');
    assert $data->{planet140};
    assert_equals $data->{planet140}{FIGHTERS}, 2;
    assert_equals $data->{planet140}{G}{MC}, 0;
    assert_equals $data->{planet140}{G}{SUPPLIES}, 95;
    assert_equals $data->{planet140}{G}{T}, 159;
    assert_equals $data->{planet140}{G}{M}, 100;
    # FIXME: 3-arg version with ship
};

test 'play/04_planet/buildengines', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet63', '[["buildengines",6,1]]', '.');
    assert $data->{planet63};
    assert_equals $data->{planet63}{'STORAGE.ENGINES'}[6], 1;
    assert_equals $data->{planet63}{G}{T}, 1645;
    assert_equals $data->{planet63}{G}{D}, 45;
    assert_equals $data->{planet63}{G}{M}, 10;
    assert_equals $data->{planet63}{G}{MC}, 669;
};

test 'play/04_planet/buildtorps', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet63', '[["buildtorps",7,3]]', '.');
    assert $data->{planet63};
    assert_equals $data->{planet63}{'STORAGE.AMMO'}[7], 17;
    assert_equals $data->{planet63}{G}{T}, 1645;
    assert_equals $data->{planet63}{G}{D}, 45;
    assert_equals $data->{planet63}{G}{M}, 22;
    assert_equals $data->{planet63}{G}{MC}, 629;
    # FIXME: 3-arg version with ship
};

test 'play/04_planet/buildhulls', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet140', '[["buildhulls",15,2]]', '.');
    assert $data->{planet140};
    assert_equals $data->{planet140}{'STORAGE.HULLS'}[1], 2;
    assert_equals $data->{planet140}{G}{T}, 161;
    assert_equals $data->{planet140}{G}{D}, 392;
    assert_equals $data->{planet140}{G}{M}, 98;
    assert_equals $data->{planet140}{G}{MC}, 154;
};

test 'play/04_planet/buildlaunchers', sub {
    my $setup = shift;
    # This base has just tech 1, so this implies an upgrade
    my $data = call_str($setup, 'POST obj/planet140', '[["buildlaunchers",2,3]]', '.');
    assert $data->{planet140};
    assert_equals $data->{planet140}{'STORAGE.LAUNCHERS'}[2], 3;
    assert_equals $data->{planet140}{G}{T}, 162;
    assert_equals $data->{planet140}{G}{D}, 396;
    assert_equals $data->{planet140}{G}{M}, 104;
    assert_equals $data->{planet140}{G}{MC}, 62;
    assert_equals $data->{planet140}{G}{SUPPLIES}, 121;
};

test 'play/04_planet/buildbeams', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet140', '[["buildbeams",4,7]]', '.');
    assert $data->{planet140};
    assert_equals $data->{planet140}{'STORAGE.BEAMS'}[4], 7;
    assert_equals $data->{planet140}{G}{T}, 158;
    assert_equals $data->{planet140}{G}{D}, 312;
    assert_equals $data->{planet140}{G}{M}, 97;
    assert_equals $data->{planet140}{G}{MC}, 104;
    assert_equals $data->{planet140}{G}{SUPPLIES}, 121;
};

test 'play/04_planet/sellsupplies', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet266', '[["sellsupplies",12]]', '.');
    assert $data->{planet266};
    assert_equals $data->{planet266}{G}{MC}, 194;
    assert_equals $data->{planet266}{G}{SUPPLIES}, 100;
};

test 'play/04_planet/buildship', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet140', '[["buildship",66,1,10,1,1,1]]', '.');
    assert $data->{planet140};
    assert $data->{planet140}{BUILD};
    assert_equals $data->{planet140}{BUILD}{HULL}, 66;
    assert_equals $data->{planet140}{BUILD}{ENGINE}, 1;
    assert_equals $data->{planet140}{BUILD}{BEAM}, 10;
    assert_equals $data->{planet140}{BUILD}{'BEAM.COUNT'}, 1;
    assert_equals $data->{planet140}{BUILD}{TORP}, 1;
    assert_equals $data->{planet140}{BUILD}{'TORP.COUNT'}, 1;
    assert_equals $data->{planet140}{G}{T}, 129;
    assert_equals $data->{planet140}{G}{D}, 370;
    assert_equals $data->{planet140}{G}{M}, 29;
    assert_equals $data->{planet140}{G}{MC}, 0;
    assert_equals $data->{planet140}{G}{SUPPLIES}, 79;
    assert_equals $data->{planet140}{'TECH.HULL'}, 2;
};

test 'play/04_planet/cargotransfer', sub {
    my $setup = shift;
    my $data = call_str($setup, 'POST obj/planet14', '[["cargotransfer","10n 3tdm 10s",308,"s"]]', '.');
    assert $data->{planet14};
    assert_equals $data->{planet14}{G}{N}, 134;
    assert_equals $data->{planet14}{G}{T}, 147;
    assert_equals $data->{planet14}{G}{D}, 29;
    assert_equals $data->{planet14}{G}{M}, 57;
    assert_equals $data->{planet14}{G}{MC}, 354;
    assert_equals $data->{planet14}{G}{SUPPLIES}, 207;

    assert $data->{ship308};
    assert_equals $data->{ship308}{CARGO}{N}, 92;
    assert_equals $data->{ship308}{CARGO}{T}, 45;
    assert_equals $data->{ship308}{CARGO}{D}, 38;
    assert_equals $data->{ship308}{CARGO}{M}, 66;
    assert_equals $data->{ship308}{CARGO}{MC}, 10;
    assert_equals $data->{ship308}{CARGO}{SUPPLIES}, 0;

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

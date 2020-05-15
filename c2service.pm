#!/usr/bin/perl -w
#
#  Common operations on services
#
package c2service;

use c2systest;
use strict;
use bytes;


##
##  Database
##

# setup_db_init(setup): initialize the database service
sub setup_db_init {
    my $setup = shift;
    my $dbc = setup_connect_app($setup, 'db');

    # -- from init.con --

    # Defaults
    conn_call($dbc, qw(set user:uid 1000));

    # No need to block user names for testing. If we want to test blocking, add that there.
    # conn_call($dbc, qw(setnx uid:root 0));
    # conn_call($dbc, qw(setnx uid:admin 0));
    # conn_call($dbc, qw(setnx uid:sysop 0));
    # conn_call($dbc, qw(setnx uid:moderator 0));

    # Default profile
    conn_call($dbc, qw(hmset default:profile limitfiles 1000 limitkbytes 20000 allowupload 1 allowadmin 0));
    conn_call($dbc, qw(hmset default:profile talkautolink 1 talkautosmiley 1 talkautowatch 1 joinautowatch 1));
    conn_call($dbc, qw(hmset default:profilecopy termsversion 1));
    conn_call($dbc, qw(hmset default:profilecopy turnreliability 90000));

    # -- from init_talk.con --

    # Defaults
    conn_call($dbc, qw(hset default:profile allowpost 1));
    conn_call($dbc, qw(hset default:profile talkautowatch 1));
    conn_call($dbc, qw(hset default:profile mailpmtype msg));

    # PM folders
    conn_call($dbc, qw(hmset default:folder:1:header name Inbox description Incoming_messages));
    conn_call($dbc, qw(sadd default:folder:all 1));
    conn_call($dbc, qw(hmset default:folder:2:header name Outbox description Sent_messages));
    conn_call($dbc, qw(sadd default:folder:all 2));
}

# setup_db_add_user($setup, $name, opt k,v,k,v): create a user.
# Note that this does not create the file system stuff!
sub setup_db_add_user {
    my $setup = shift;
    my $name = shift;
    my $dbc = setup_connect_app($setup, 'db');

    my $uid = conn_call($dbc, qw(incr user:uid));
    conn_call($dbc, 'set', "user:$uid:password", 'x');     # user will not be able to log in
    conn_call($dbc, 'hmset', "user:$uid:profile",
              'screenname', $name,
              'createtime', 1502479766,
              @{ conn_call($dbc, 'hgetall', 'default:profilecopy') },
              @_);
    conn_call($dbc, 'set', "user:$uid:name", $name);
    conn_call($dbc, 'set', "uid:$name", $uid);
    conn_call($dbc, 'sadd', 'user:all', $uid);

    $uid;
}

# setup_add_user($setup, $name, opt k,v,k,v): create a user.
sub setup_add_user {
    # Create user in DB
    my $setup = shift;
    my $name = shift;
    my $uid = setup_db_add_user($setup, $name, @_);

    # Create filesystem stuff
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, 'mkdirhier', 'u');
    conn_call($ufc, 'mkdiras', 'u/'.$name, $uid);

    $uid;
}


##
##  Talk
##

# setup_talk_init(setup): Initialize. This needs a TALK and DB service!
sub setup_talk_init {
    my $setup = shift;
    my $talkc = setup_connect_app($setup, 'talk');
    my $dbc = setup_connect_app($setup, 'db');

    # Add groups
    conn_call($talkc, qw(groupadd root              key root));
    conn_call($talkc, qw(groupadd active            key 0100-active));
    conn_call($talkc, qw(groupadd finished          key 0200-finished));
    conn_call($talkc, qw(groupadd active-unlisted   key 0101-active));
    conn_call($talkc, qw(groupadd finished-unlisted key 0201-finished));

    # Configure groups
    conn_call($talkc, qw(groupset root              name), "All forums",     "description", "text:All forums",                qw(key root          parent), "");
    conn_call($talkc, qw(groupset active            name), "Active Games",   "description", "text:Forums for active games",   qw(key 0100-active   parent), "root");
    conn_call($talkc, qw(groupset finished          name), "Finished Games", "description", "text:Forums for finished games", qw(key 0200-finished parent), "root");
    conn_call($talkc, qw(groupset active-unlisted   name), "Active Games",   "description", "text:Forums for active games",   qw(key 0101-active   parent), "", "unlisted", 1);
    conn_call($talkc, qw(groupset finished-unlisted name), "Finished Games", "description", "text:Forums for finished games", qw(key 0201-finished parent), "", "unlisted", 1);

    # Create forums (fewer than normal)
    # - News
    my $f = conn_call($talkc, qw(forumadd parent root));
    conn_call($dbc, "hset", "forum:byname", "news", $f);
    conn_call($talkc, "forumset", $f, "name", "News", "description", "text:News and Announcements about PlanetsCentral");
    conn_call($talkc, "forumset", $f, "newsgroup", "planetscentral.news", "key", "0001-news");
    conn_call($talkc, "forumset", $f, "readperm", "all", "writeperm", "p:allowadmin", "answerperm", "-u:anon,p:allowpost");

    # - Talk
    $f = conn_call($talkc, qw(forumadd parent talk));
    conn_call($dbc, "hset", "forum:byname", "talk", $f);
    conn_call($talkc, "forumset", $f, "name", "Talk", "description", "text:Everything: VGAP, RL, or otherwise");
    conn_call($talkc, "forumset", $f, "newsgroup", "planetscentral.talk", "key", "0004-talk");
    conn_call($talkc, "forumset", $f, "readperm", "all", "writeperm", "-u:anon,p:allowpost", "answerperm", "-u:anon,p:allowpost");
}



##
##  Hostfile
##

# setup_hostfile_add_defaults(setup): add default files to hostfile service
sub setup_hostfile_add_defaults {
    # Parameters
    my $setup = shift;
    my $hfc = setup_connect_app($setup, 'hostfile');

    # Initialize directories
    foreach (qw(bin defaults games tools shiplist)) {
        conn_call($hfc, 'mkdirhier', $_);
    }
    conn_call($hfc, qw(setperm shiplist * rl));

    # Generated files
    conn_call($hfc, qw(put defaults/planet.nm), _generate_file(500, 20, 'Planet %d'));
    conn_call($hfc, qw(put defaults/storm.nm),  _generate_file(50, 20, 'Storm %d'));
    conn_call($hfc, qw(put defaults/race.nm), vp_race_names());
    conn_call($hfc, qw(put defaults/xyplan.dat), _generate_map());
}

# setup_get_init_scripts($setup): get path to init scripts. Needs c2ng.
sub setup_get_init_scripts {
    my $setup = shift;
    # Assuming c2ng points at a completely-installed directory ('make install')
    my $bindir = setup_get_required_system_config($setup, 'c2ng').'/../share/server/scripts/init';
    if (!-d $bindir) {
        # Assuming c2ng points at a build directory that is child of a source directory ('make all resources')
        $bindir = setup_get_required_system_config($setup, 'c2ng').'/../server/scripts/init';
    }
    if (!-d $bindir) {
        die "Unable to locate host scripts"
    }
    $bindir;
}

# setup_hostfile_add_default_scripts($setup): add default scripts. Requires c2server. Call after setup_hostfile_add_defaults.
sub setup_hostfile_add_default_scripts {
    my $setup = shift;
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $bindir = setup_get_init_scripts($setup); 
    foreach (qw(runhost.sh runmaster.sh checkturn.sh updateconfig.pl checkinstall.sh)) {
        conn_call($hfc, 'put', 'bin/'.$_, file_content($bindir.'/bin/'.$_));
    }
}


##
##  Host
##

# setup_host_add_phost($setup, $name, $srcdir)
# ex planetscentral/scripts/upload_phost4.con. Change: does not create -current, does not upload pconfig.src.frag, does not set default/description.
sub setup_host_add_phost {
    my ($setup, $name, $srcdir) = @_;
    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');

    test_failure('Missing $srcdir') if !defined $srcdir;

    # Upload
    my $dstdir = 'tools/'.$name;
    conn_call($hfc, 'mkdir', $dstdir);
    foreach (qw(mission.ini phost plang4.hst)) {
        conn_call($hfc, 'put', "$dstdir/$_", file_content("$srcdir/$_"));
    }
    conn_call($hfc, 'put', "$dstdir/pconfig.src", file_content("$srcdir/config/simple.src"));

    # Add to host
    conn_call($hc, 'hostadd', $name, $dstdir, 'phost', 'phost');
    conn_call($hc, 'hostset', $name, 'description', "c2systest phost upload from $srcdir");
}

# setup_host_add_amaster($setup, $name, $srcdir)
# ex planetscentral/scripts/upload_amaster.con. Change: does not set default.
sub setup_host_add_amaster {
    my ($setup, $name, $srcdir) = @_;
    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');

    test_failure('Missing $srcdir') if !defined $srcdir;

    # Upload
    my $dstdir = "tools/$name";
    conn_call($hfc, 'mkdir', $dstdir);
    conn_call($hfc, 'put', "$dstdir/amaster", file_content("$srcdir/amaster"));
    conn_call($hfc, 'put', "$dstdir/amaster.src", file_content("$srcdir/../config/amaster.src"));

    # Add to host
    conn_call($hc, 'masteradd', $name, $dstdir, 'amaster', 'amaster');
    conn_call($hc, 'masterset', $name, 'description', "c2systest amaster upload from $srcdir");
    conn_call($hc, 'masterrating', $name, 'none');
}

# setup_host_add_shiplist($setup, $name, $srcdir, $kind)
# ex planetscentral/scripts/upload_shiplist.con. Changes: totally simplified config/error handling.
sub setup_host_add_shiplist {
    my ($setup, $name, $srcdir, $kind) = @_;
    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');

    test_failure('Missing $srcdir') if !defined $srcdir;
    test_failure('Missing $kind') if !defined $kind;

    # Upload
    my $dstdir = "shiplist/$name";
    conn_call($hfc, 'mkdir', $dstdir);
    foreach (qw(beamspec.dat engspec.dat hullspec.dat torpspec.dat truehull.dat shiplist.txt hullfunc.txt pconfig.src.frag)) {
        conn_call($hfc, 'put', "$dstdir/$_", file_content("$srcdir/$_")) if -r "$srcdir/$_";
    }
    conn_call($hfc, 'setperm', $dstdir, '*', 'rl');

    # Add to host
    conn_call($hc, 'shiplistadd', $name, $dstdir, '', $kind);
    conn_call($hc, 'shiplistset', $name, 'description', "c2systest shiplist upload from $srcdir");
    conn_call($hc, 'shiplistrating', $name, 'auto', 'show');
}

sub _generate_file {
    my ($num, $len, $fmt) = @_;
    my $result = '';
    for (my $i = 1; $i <= $num; ++$i) {
        $result .= sprintf("%-${len}s", sprintf($fmt, $i));
    }
    $result;
}

sub _generate_map {
    my @result;
    foreach (1..500) {
        push @result, 1000 + (50 * $_ % 50), 1000 + (50 * int($_ / 30)), 0;
    }
    pack "v*", @result;
}






# For reference, remaining initialisation tasks for user filer:
#
# ifset init noerror file rmdir u
# ifset init noerror file rmdir r
# ifset init noerror file rmdir d
#
# # User data directory (initially empty)
# silent noerror file mkdir u
#
# # Server reg keys
# noerror file mkdir r
# noerror file mkdir r/unreg
# silent file put r/unreg/fizz.bin <${dir}/fizz.bin
# silent file setperm r/unreg * r
# silent file setperm r * r
#
# # Demo games
# noerror file mkdir d
# silent file setperm d * r
#
# noerror file mkdir d/tim
# silent file setperm d/tim * r
# silent file propset d/tim name "Tim's demo RST"
# silent file put d/tim/player11.rst <${dir}/d/tim/player11.rst
# silent file put d/tim/fizz.bin     <${dir}/d/tim/fizz.bin

##
##  VGAP Logic
##

# vp_make_turn($player, $time, @commands): Make a turn file.
#   player: player number [1..11]
#   time: timestamp (18 characters)
#   commands: binary commands, e.g. 'pack("V*", 12, 39, 500)' for ShipChangeTritanium(ShipId 39, Tritanium 500)
sub vp_make_turn {
    my ($player, $time, @cmds) = @_;

    # Header
    $time = substr($time, 0, 18);
    my $tscheck = _checksum($time);
    my $header = pack("vVA18vv", $player, scalar(@cmds), $time, 0, $tscheck);
    $header .= 'x' if @cmds;

    # Pointers
    my $pointers = '';

    # Body
    my $body = '';
    foreach (@cmds) {
        $pointers .= pack("V", length($header) + 4*scalar(@cmds) + 1 + length($body));
        $body .= $_;
    }

    # Trailer
    my $checksum = _checksum($header) + _checksum($pointers) + _checksum($body) + 3*$tscheck + 13;
    my @sig = (map {416*$_} 1..25) x 2;
    $sig[0] += 13*($player + 16);
    my $sigsum = 668;
    foreach (@sig) { $sigsum += $_ }
    my @log = (1..11);
    $log[$player-1] = $checksum;
    my $trailer = pack("V*", $checksum, 42, @sig, $sigsum, @log);

    # Result
    $header.$pointers.$body.$trailer;
};

sub vp_race_names {
    _generate_file(11, 30, 'Long Race %d')._generate_file(11, 20, 'Short Race %d')._generate_file(11, 12, 'Adj %d')
}

# vp_make_empty_result_file($player, $timestamp): make an empty result file.
# The file parses valid, but has no content.
sub vp_make_empty_result_file {
    my $player = shift;
    my $timestamp = sprintf("%18s", shift);
    my $gen = join('',
                   $timestamp,                  # time
                   "\0" x 88,                   # scores
                   pack("v", $player),          # player
                   "x" x 20,                    # password [not valid]
                   "\0" x 12,                   # checksums
                   "\5\0",                      # turn 5
                   pack "v", _checksum($timestamp)); # timestamp sum
    my @content = ("\0\0",          # ships
                   "\0\0",          # VCs
                   "\0\0",          # planets
                   "\0\0",          # bases
                   "\0\0",          # messages
                   "\0" x 4000,     # shipxy
                   $gen,            # gen
                   "\0\0");         # vcrs
    my $pos = 1 + 8*4;
    my $result = "";
    foreach (@content) {
        $result .= pack "V", $pos;
        $pos += length($_);
    }
    join ("", $result, @content);
}

sub _checksum {
    my $s = shift;
    my $sum = 0;
    for (my $i = 0; $i < length($s); ++$i) {
        $sum += ord(substr($s, $i, 1));
    }
    return $sum;
}



1;

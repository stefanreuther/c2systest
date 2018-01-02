#!/usr/bin/perl -w
#
#  mgrep: basic functionality test
#
use strict;
use c2systest;

sub test_it {
    my ($name, $infile, $outfile, $query) = @_;

    test 'mgrep/01_base/'.$name, sub {
        my $setup = shift;
        my $shell = shell_new($setup, 'mgrep');
        shell_add_args($shell, '-z', $query, $infile);
        assert_equals shell_call($shell), file_content($outfile);
    };
}

# Simple cases (just one message type).
test_it 'inbox', 'mgrep/test_inbox.dat', 'mgrep/test_inbox.txt', 'B0DA';
test_it 'out30', 'mgrep/test_out30.dat', 'mgrep/test_out30.txt', 'kablla';
test_it 'out35', 'mgrep/test_out35.dat', 'mgrep/test_out35.txt', 'chaachaa';
test_it 'rst',   'mgrep/test_rst.rst',   'mgrep/test_rst.txt',   '9D28';
test_it 'trn',   'mgrep/test_trn.trn',   'mgrep/test_trn.txt',   'ZZkkk';

# test_vpa contains just incoming messages whereas test_vpa2 also contains outgoing.
test_it 'vpa',   'mgrep/test_vpa.db',    'mgrep/test_vpa.txt',   '2366';
test_it 'vpa',   'mgrep/test_vpa2.db',   'mgrep/test_vpa2.txt',  '1520';

# test_zip contains the same RST as test_rst.
test_it 'zip',   'mgrep/test_zip.zip',   'mgrep/test_zip.txt',   '9D28';

#!/usr/bin/perl -w
#
#  c2play-server: fcode properties
#
use strict;
use c2systest;

# Test retrieving friendly code list.
# A: GET friendly code list
# E: verify properties are as expected
test 'play/06_fcode', sub {
    my $setup = shift;
    my $data = call_str($setup, "GET obj/fcode");

    assert $data->{fcode};

    # Verify selected fcodes
    # - "AAA"
    my @f = grep {$_->{NAME} eq 'AAA'} @{$data->{fcode}};
    assert @f;
    assert_equals $f[0]{RACES}, 2;
    assert_equals $f[0]{DESCRIPTION}, 'New Fed Ship';
    assert_equals $f[0]{FLAGS}, 'su';

    @f = grep {$_->{NAME} eq 'bum'} @{$data->{fcode}};
    assert @f;
    assert_equals $f[0]{RACES}, -1;
    assert_equals $f[0]{DESCRIPTION}, 'Beam up money';
    assert_equals $f[0]{FLAGS}, 'p';

    @f = grep {$_->{NAME} eq 'mi2'} @{$data->{fcode}};
    assert @f;
    assert_equals $f[0]{RACES}, -1;
    assert_equals $f[0]{DESCRIPTION}, 'Lay a Lizard mine field';
    assert_equals $f[0]{FLAGS}, 'scr';
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

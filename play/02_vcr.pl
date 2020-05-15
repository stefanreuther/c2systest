#!/usr/bin/perl -w
#
#  VCR sanitation
#
use strict;
use c2systest;

# Test VCR sanitation.
# E: Create a result file with our standard VCR content. Load it.
# A: Verify that loader has santitised the file (see comment below).
test 'play/02_vcr', sub {
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $dir, 0777 or die "$dir: $!";

    # Build a dummy result
    my @offsets;
    my $payload = pack('v', 0);     # 0 bytes for empty sections

    # - section 1 - 5: ships, targets, planets, bases, messages
    push @offsets, (0) x 5;

    # - section 6: shipxy
    push @offsets, length($payload);
    $payload .= "\0" x (500*8);

    # - section 7: gen
    push @offsets, length($payload);
    $payload .= '01-02-200010:20:30';       # Timestamp
    $payload .= "\0" x 88;                  # Scores
    $payload .= pack('v', 7);               # Player
    $payload .= 'NOPASSWORD          ';     # Password
    $payload .= pack('V*', 0, 0, 0);        # Checksums
    $payload .= pack('v', 42);              # Turn number
    $payload .= pack('v', 889);             # Time checksum

    # - section 8: VCRs
    push @offsets, length($payload);
    $payload .= file_content(cmdl_input_file('vcr2.dat'));

    # Adjust
    foreach (@offsets) {
        $_ += 33;
    }

    # Create file
    file_put("$dir/player7.rst", pack("V*", @offsets).$payload);

    # Load with c2server
    my $shell = shell_new($setup, 'server');
    shell_add_args($shell, $dir, 7);

    my @out = split /\n/, shell_call($shell, "GET obj/zvcr\n");
    assert_starts_with shift(@out), '100';
    assert_starts_with shift(@out), '200';
    assert_equals pop(@out), '.';

    my $data = json_parse(join("\n", @out));
    assert_equals scalar(@{$data->{zvcr}}), 17;

    # Verify first VCR.
    #   unit[0].shield has value 100 in the binary data, although the VCR needs to treat it as 0.
    #   This special handling used to be in the VCR player, but has been moved into the loader
    #   to allow the player to play Nu's specialties. Since the JavaScript side uses the new
    #   interpretation since May 2019, all implementations need to agree on this split.
    my $vcr = $data->{zvcr}[0];
    assert_equals $vcr->{SEED}, 42;
    assert_equals $vcr->{UNIT}[0]{'BEAM.COUNT'}, 0;
    assert_equals $vcr->{UNIT}[0]{'FIGHTER.COUNT'}, 0;
    assert_equals $vcr->{UNIT}[0]{'TORP.LCOUNT'}, 0;
    assert_equals $vcr->{UNIT}[0]{'SHIELD'}, 0;

    assert_equals $vcr->{UNIT}[1]{'BEAM.COUNT'}, 6;
    assert_equals $vcr->{UNIT}[1]{'FIGHTER.COUNT'}, 0;
    assert_equals $vcr->{UNIT}[1]{'TORP.LCOUNT'}, 4;
    assert_equals $vcr->{UNIT}[1]{'SHIELD'}, 100;
};

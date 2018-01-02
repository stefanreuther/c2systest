#!/usr/bin/perl -w
#
#  Host: Format
#
#  Synced with TestServerFormatFormat, 20170925
#
use strict;
use c2systest;
use c2service;

# TestServerFormatFormat::testPack
test 'format/50_format/pack', sub {
    my $setup = shift;
    my $fc = prepare($setup);

    # Simple string, plain
    assert_equals conn_call($fc, 'pack', 'string', 'x'), 'x';

    # Simple string, tagged "obj"
    assert_equals conn_call($fc, 'pack', 'string', 'x', 'format', 'obj'), 'x';

    # Simple string with umlaut, default charset (latin1)
    assert_equals conn_call($fc, 'pack', 'string', "\xC3\xA4"), "\xE4";

    # Simple string with umlaut, given a charset
    assert_equals conn_call($fc, 'pack', 'string', "\xC3\xA4", 'charset', 'cp437'), "\x84";

    # Truehull, given as partial JSON
    my $result = conn_call($fc, 'pack', 'truehull', '[[1,2,3],[4,5,6]]', 'format', 'json');
    assert_equals length($result), 440;
    assert_equals substr($result, 0, 6), "\1\0\2\0\3\0";
    assert_equals substr($result, 40, 2), "\4\0";

    # JSON string
    assert_equals conn_call($fc, 'pack', 'string', '"x"', 'format', 'json'), 'x';

    # Error: not JSON
    # produces unnumbered message
    assert_throws sub{ conn_call($fc, 'pack', 'string', 'x', 'format', 'json') };

    # Error: bad type name
    assert_throws sub{ conn_call($fc, 'pack', 'what', 'x') }, qr{415|Invalid};
    assert_throws sub{ conn_call($fc, 'pack', '', 'x') }, qr{415|Invalid};

    # Error: bad format name
    assert_throws sub{ conn_call($fc, 'pack', 'string', 'x', 'format', 'what') }, qr{415|Invalid};
    assert_throws sub{ conn_call($fc, 'pack', 'string', 'x', 'format', '') }, qr{415|Invalid};

    # Error: bad charset name
    assert_throws sub{ conn_call($fc, 'pack', 'string', 'x', 'charset', 'what') }, qr{415|Invalid};
    assert_throws sub{ conn_call($fc, 'pack', 'string', 'x', 'charset', '') }, qr{415|Invalid};
};

# TestServerFormatFormat::testUnpack: Test unpack.
test 'format/50_format/unpack', sub {
    my $setup = shift;
    my $fc = prepare($setup);

    # Simple string, plain
    assert_equals conn_call($fc, 'unpack', 'string', 'x'), 'x';

    # Simple string, tagged "obj"
    assert_equals conn_call($fc, 'unpack', 'string', 'x', 'format', 'obj'), 'x';

    # Simple string with umlaut, default charset (latin1)
    assert_equals conn_call($fc, 'unpack', 'string', "\xE4"), "\xC3\xA4";

    # Simple string with umlaut, given a charset
    assert_equals conn_call($fc, 'unpack', 'string', "\x84", 'charset', 'cp437'), "\xC3\xA4";

    # JSON string
    my $result = conn_call($fc, 'unpack', 'string', 'x', 'format', 'json');
    chomp $result;                          # -classic produces trailing newline
    assert_equals $result, '"x"';

    # Error: bad type name
    assert_throws sub{ conn_call($fc, 'unpack', 'what', 'x') }, qr{415|Invalid};
    assert_throws sub{ conn_call($fc, 'unpack', '', 'x') }, qr{415|Invalid};

    # Error: bad format name
    assert_throws sub{ conn_call($fc, 'unpack', 'string', 'x', 'format', 'what') }, qr{415|Invalid};
    assert_throws sub{ conn_call($fc, 'unpack', 'string', 'x', 'format', '') }, qr{415|Invalid};

    # Error: bad charset name
    assert_throws sub{ conn_call($fc, 'unpack', 'string', 'x', 'charset', 'what') }, qr{415|Invalid};
    assert_throws sub{ conn_call($fc, 'unpack', 'string', 'x', 'charset', '') }, qr{415|Invalid};
};

# TestServerFormatFormat::testUnpackAll: Test unpack() with a multitude of formats.
#    This mainly exercises the Packer factory function; the individual packers already have their test.
test 'format/50_format/multi', sub {
    my $setup = shift;
    my $fc = prepare($setup);

    # Engines
    my @result = conn_call_list_of_hash($fc, 'unpack', 'engspec',
                                        "\x53\x74\x61\x72\x44\x72\x69\x76\x65\x20\x31\x20\x20\x20\x20\x20".
                                        "\x20\x20\x20\x20\x01\x00\x05\x00\x01\x00\x00\x00\x01\x00\x64\x00".
                                        "\x00\x00\x20\x03\x00\x00\x8c\x0a\x00\x00\x00\x19\x00\x00\xd4\x30".
                                        "\x00\x00\x60\x54\x00\x00\xfc\x85\x00\x00\x00\xc8\x00\x00\xc4\x1c".
                                        "\x01\x00");
    assert_equals $result[0]{NAME}, 'StarDrive 1';
    assert_equals $result[0]{FUELFACTOR}[9], 72900;

    # Beams
    @result = conn_call_list_of_hash($fc, 'unpack', 'beamspec',
                                     "\x4c\x61\x73\x65\x72\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20".
                                     "\x20\x20\x20\x20\x01\x00\x01\x00\x00\x00\x00\x00\x01\x00\x01\x00".
                                     "\x0a\x00\x03\x00");
    assert_equals $result[0]{NAME}, 'Laser';
    assert_equals $result[0]{KILL}, 10;

    # Torpedoes
    @result = conn_call_list_of_hash($fc, 'unpack', 'torpspec',
                                     "\x4d\x61\x72\x6b\x20\x31\x20\x50\x68\x6f\x74\x6f\x6e\x20\x20\x20".
                                     "\x20\x20\x20\x20\x01\x00\x01\x00\x01\x00\x01\x00\x00\x00\x02\x00".
                                     "\x01\x00\x04\x00\x05\x00");
    assert_equals $result[0]{NAME}, 'Mark 1 Photon';
    assert_equals $result[0]{DAMAGE1}, 5;

    # Hulls
    @result = conn_call_list_of_hash($fc, 'unpack', 'hullspec',
                                     "\x4e\x4f\x43\x54\x55\x52\x4e\x45\x20\x43\x4c\x41\x53\x53\x20\x44".
                                     "\x45\x53\x54\x52\x4f\x59\x45\x52\x20\x20\x20\x20\x20\x20\x0a\x00".
                                     "\x01\x00\x32\x00\x19\x00\x07\x00\xb4\x00\xbe\x00\x01\x00\x5a\x00".
                                     "\x02\x00\x32\x00\x00\x00\x02\x00\x04\x00\x46\x00");
    assert_equals $result[0]{NAME}, 'NOCTURNE CLASS DESTROYER';
    assert_equals $result[0]{MASS}, 90;

    # Simulation
    my %sim = conn_call_list($fc, 'unpack', 'sim',
                             "\x43\x43\x62\x73\x69\x6d\x30\x1a\x01\x80\x53\x68".
                             "\x69\x70\x20\x32\x30\x31\x20\x20\x20\x20\x20\x20".
                             "\x20\x20\x20\x20\x20\x20\x00\x00\x60\x01\xc9\x00".
                             "\x08\x00\x00\x00\x06\x00\x06\x00\x04\x00\x00\x00".
                             "\x55\x00\x00\x00\x09\x00\x4c\x00\x64\x00\x3f\x3f".
                             "\x3f\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00".
                             "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".
                             "\x00\x00\x00\xcb\x01\x06\x00\x00\x00\x01\x00\x00".
                             "\x00\x16\x00\x00\x00\x00\x00\x01\x00\x96\x00\x81".
                             "\x00\x00\x00\x4e\x55\x4b\x00\x00");
    my %ship = @{$sim{ships}[0]};
    assert_equals $ship{NAME}, 'Ship 201';
    assert_equals $ship{HULL}, 76;

    # Unpacking a simulation can fail
    # (unnumbered error message)
    assert_throws sub{ conn_call($fc, 'unpack', 'sim', "\x43\x43\x62\x73\x69\x6d\x30\x00") };
};


sub prepare {
    my $setup = shift;
    my $service = setup_add_app($setup, 'format', 'c2format');
    setup_start_wait($setup);
    return service_connect($service);
}

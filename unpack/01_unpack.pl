#!/usr/bin/perl -w
#
#  c2unpack: variants
#

use c2systest;
use c2service;
use Digest::MD5 ('md5_hex');

# Test default unpack.
# Reference values have been created using "ccunpack /w".
test 'check/01_unpack/default', sub {
    my $setup = shift;
    my $gd = create_folder($setup);
    run_unpack($setup, $gd);
    verify_files($gd, qw(02765861886e4f26c513be1db42cc37b  bdata7.dat
                         0a98f879cc0e9a580eb43c6f0955d8d3  bdata7.dis
                         5f862ec479719b3da4190c67e6abb495  contrl7.dat
                         bdb495bb546bede4c26132c40542f0e6  gen7.dat
                         584c31dbdfdd8360acb36a03f36584c2  init.tmp
                         a84e29fa1a8d7648647259cd7635c34a  kore7.dat
                         e0245bea1f6731c1bf509b666b286d08  mdata7.dat
                         c4103f122d27677c9db144cae1394a66  mess357.dat
                         c3d10c5928dda536b502571a64ce6092  pdata7.dat
                         5f2f2237b1aaaab4fbb4e89462828ada  pdata7.dis
                         f3944795d20b4db50a2cafb49a495622  race.nm
                         239af4ecfbe14b46cbaccfe4cb745be7  ship7.dat
                         35ac3d995678b0f758daca1b13bd9e05  ship7.dis
                         107b0182ac6a01db96c6c1d0a1f47cdb  shipxy7.dat
                         7a0a8a3d5c22d07fbfd1ae9884988010  target7.dat
                         7ed5126653a8e20b8a93fadeeb78af4d  vcr7.dat));
};

# Test unpack with target file.
# Reference values have been created using "ccunpack /w /t".
test 'check/01_unpack/ext', sub {
    my $setup = shift;
    my $gd = create_folder($setup);
    run_unpack($setup, $gd, '-t');
    verify_files($gd, qw(02765861886e4f26c513be1db42cc37b  bdata7.dat
                         0a98f879cc0e9a580eb43c6f0955d8d3  bdata7.dis
                         5f862ec479719b3da4190c67e6abb495  contrl7.dat
                         bdb495bb546bede4c26132c40542f0e6  gen7.dat
                         584c31dbdfdd8360acb36a03f36584c2  init.tmp
                         a84e29fa1a8d7648647259cd7635c34a  kore7.dat
                         e0245bea1f6731c1bf509b666b286d08  mdata7.dat
                         c4103f122d27677c9db144cae1394a66  mess357.dat
                         c3d10c5928dda536b502571a64ce6092  pdata7.dat
                         5f2f2237b1aaaab4fbb4e89462828ada  pdata7.dis
                         f3944795d20b4db50a2cafb49a495622  race.nm
                         239af4ecfbe14b46cbaccfe4cb745be7  ship7.dat
                         35ac3d995678b0f758daca1b13bd9e05  ship7.dis
                         107b0182ac6a01db96c6c1d0a1f47cdb  shipxy7.dat
                         7a0a8a3d5c22d07fbfd1ae9884988010  target7.dat
                         0a39789a188b523c02b7539f0cca6d95  target7.ext
                         7ed5126653a8e20b8a93fadeeb78af4d  vcr7.dat));
};

# Test unpack with DOS format.
# Reference values have been created using "ccunpack".
test 'check/01_unpack/dos', sub {
    my $setup = shift;
    my $gd = create_folder($setup);
    run_unpack($setup, $gd, '-d');
    verify_files($gd, qw(02765861886e4f26c513be1db42cc37b  bdata7.dat
                         0a98f879cc0e9a580eb43c6f0955d8d3  bdata7.dis
                         5f862ec479719b3da4190c67e6abb495  control.dat
                         bdb495bb546bede4c26132c40542f0e6  gen7.dat
                         584c31dbdfdd8360acb36a03f36584c2  init.tmp
                         a84e29fa1a8d7648647259cd7635c34a  kore7.dat
                         e0245bea1f6731c1bf509b666b286d08  mdata7.dat
                         c4103f122d27677c9db144cae1394a66  mess7.dat
                         c3d10c5928dda536b502571a64ce6092  pdata7.dat
                         5f2f2237b1aaaab4fbb4e89462828ada  pdata7.dis
                         f3944795d20b4db50a2cafb49a495622  race.nm
                         239af4ecfbe14b46cbaccfe4cb745be7  ship7.dat
                         35ac3d995678b0f758daca1b13bd9e05  ship7.dis
                         107b0182ac6a01db96c6c1d0a1f47cdb  shipxy7.dat
                         7a0a8a3d5c22d07fbfd1ae9884988010  target7.dat
                         7ed5126653a8e20b8a93fadeeb78af4d  vcr7.dat));
};

# Test unpack with DOS format, target.ext file.
# Reference values have been created using "ccunpack /t".
test 'check/01_unpack/dos+ext', sub {
    my $setup = shift;
    my $gd = create_folder($setup);
    run_unpack($setup, $gd, '-d', '-t');
    verify_files($gd, qw(02765861886e4f26c513be1db42cc37b  bdata7.dat
                         0a98f879cc0e9a580eb43c6f0955d8d3  bdata7.dis
                         5f862ec479719b3da4190c67e6abb495  control.dat
                         bdb495bb546bede4c26132c40542f0e6  gen7.dat
                         584c31dbdfdd8360acb36a03f36584c2  init.tmp
                         a84e29fa1a8d7648647259cd7635c34a  kore7.dat
                         e0245bea1f6731c1bf509b666b286d08  mdata7.dat
                         c4103f122d27677c9db144cae1394a66  mess7.dat
                         c3d10c5928dda536b502571a64ce6092  pdata7.dat
                         5f2f2237b1aaaab4fbb4e89462828ada  pdata7.dis
                         f3944795d20b4db50a2cafb49a495622  race.nm
                         239af4ecfbe14b46cbaccfe4cb745be7  ship7.dat
                         35ac3d995678b0f758daca1b13bd9e05  ship7.dis
                         107b0182ac6a01db96c6c1d0a1f47cdb  shipxy7.dat
                         7a0a8a3d5c22d07fbfd1ae9884988010  target7.dat
                         0a39789a188b523c02b7539f0cca6d95  target7.ext
                         7ed5126653a8e20b8a93fadeeb78af4d  vcr7.dat));
};

# Test unpack with DOS format, ignore 3.5 part.
# Reference values have been created using "ccunpack /a".
test 'check/01_unpack/old', sub {
    my $setup = shift;
    my $gd = create_folder($setup);
    run_unpack($setup, $gd, '-d', '-a');
    verify_files($gd, qw(02765861886e4f26c513be1db42cc37b  bdata7.dat
                         0a98f879cc0e9a580eb43c6f0955d8d3  bdata7.dis
                         5f862ec479719b3da4190c67e6abb495  control.dat
                         bdb495bb546bede4c26132c40542f0e6  gen7.dat
                         584c31dbdfdd8360acb36a03f36584c2  init.tmp
                         e0245bea1f6731c1bf509b666b286d08  mdata7.dat
                         c4103f122d27677c9db144cae1394a66  mess7.dat
                         c3d10c5928dda536b502571a64ce6092  pdata7.dat
                         5f2f2237b1aaaab4fbb4e89462828ada  pdata7.dis
                         239af4ecfbe14b46cbaccfe4cb745be7  ship7.dat
                         35ac3d995678b0f758daca1b13bd9e05  ship7.dis
                         107b0182ac6a01db96c6c1d0a1f47cdb  shipxy7.dat
                         7a0a8a3d5c22d07fbfd1ae9884988010  target7.dat
                         7ed5126653a8e20b8a93fadeeb78af4d  vcr7.dat));
};




sub create_folder {
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $dir, 0777 or die "$dir: $!";
    file_put("$dir/player7.rst", file_content("data/game3/player7.rst"));
    $dir;
}


sub run_unpack {
    my ($setup, $dir, @args) = @_;
    my $shell = shell_new($setup, 'unpack');

    # Root directory: we need a race.nm file present.
    # If no root directory is given, c2unpack will use the /usr/share directory.
    # - PCC2 will not unpack a race.nm file if it would be identical to the present one.
    #   We therefore need to make it see an different dummy file.
    # - c2ng will need a race.nm file to write a DOS-style message file.
    #   None of our testcases actually use the content of the race name file, though.
    my $root = setup_get_tmpfile_name($setup, 'rd');
    mkdir $root, 0777 or die "$root: $!";
    file_put("$root/race.nm", '.' x 682);

    shell_add_args($shell, $dir, @args, $root);
    my $shell_result = shell_call($shell);
    assert $shell_result !~ /ERROR/i;
}

sub verify_files {
    my $gd = shift;
    while (@_) {
        my $hash = shift;
        my $file = shift;
        assert_equals md5_hex(file_content("$gd/$file")), $hash
            unless $hash =~ /^#/;
    }
}

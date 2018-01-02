#!/usr/bin/perl -w
#
#  Script: basic tests
#
use strict;
use c2systest;

# Test "-S"
test 'script/01_base/S', sub {
    my $setup = shift;

    my $fn = setup_get_tmpfile_name($setup, 't.q');
    file_put($fn, "print 'hi'\n");

    my $sh = shell_new($setup, 'script');
    shell_add_args($sh, '-S', $fn, '-s');

    my $output = shell_call($sh);
    assert_equals $output, ("Sub BCO1\n".
                            "  .name -\n".
                            "    pushlit         \"hi\"\n".
                            "    sprint\n".
                            "EndSub\n".
                            "\n");
};

# Test "-S -o"
test 'script/01_base/So', sub {
    my $setup = shift;

    my $fn = setup_get_tmpfile_name($setup, 't.q');
    file_put($fn, "print 'hi'\n");

    my $ofn = setup_get_tmpfile_name($setup, 't.qs');

    my $sh = shell_new($setup, 'script');
    shell_add_args($sh, '-S', $fn, '-s', '-o', $ofn);

    my $output = shell_call($sh);
    assert_equals $output, '';
    assert_equals file_content($ofn), ("Sub BCO1\n".
                                       "  .name -\n".
                                       "    pushlit         \"hi\"\n".
                                       "    sprint\n".
                                       "EndSub\n".
                                       "\n");
};

# Test "-S -c"
test 'script/01_base/Sc', sub {
    my $setup = shift;

    my $fn = setup_get_tmpfile_name($setup, 't.q');
    file_put($fn, "print 'hi'\n");

    my $sh = shell_new($setup, 'script');
    shell_add_args($sh, '-S', $fn, '-s', '-c', '-q');

    my $output = shell_call($sh);
    assert_equals $output, '';

    # Compare bytecode file. Since this is a simple file, we can compare the whole file.
    # Variables that could cause this comparison to fail are:
    # - the Id of the bytecode object <<entry>>, <<ID 1>> is actually arbitrary.
    # - the file size could be optimized by stripping property headers 5..8 which are empty.
    assert_equals file_content($fn.'c'),
                               # CCobj^Z                 v100    hdrsz   <<entry>>       Typ:BCO
                               "\x43\x43\x6f\x62\x6a\x1a\x64\x00\x04\x00\x01\x00\x00\x00\x01\x00".
                               #        <<ID 1>>         size            #prop           count0
                               "\x00\x00\x01\x00\x00\x00\x60\x00\x00\x00\x09\x00\x00\x00\x00\x00".
                               #         size0           count1          size1           count2
                               "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00\x00\x00\x01\x00".
                               #         size2           count3          size3           count4
                               "\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00".
                               #         size4           count5          size5           count6
                               "\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".
                               #         size6           count7          size7           count8
                               "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".
                               #         size8           flag    minargs maxargs #labels longstr
                               "\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x06".
                               # stringlength    strdata pushlit #0      sprint
                               "\x02\x00\x00\x00\x68\x69\x00\x00\x05\x00\x00\x00\x0d\x0b";
};


# Test "-S -k"
test 'script/01_base/Sk', sub {
    my $setup = shift;

    # Note that we cannot currently pass command-line arguments containing spaces.
    my $sh = shell_new($setup, 'script');
    shell_add_args($sh, '-S', '-k', 'Print', '-s');

    my $output = shell_call($sh);
    assert_equals $output, ("Sub BCO1\n".
                            "  .name -\n".
                            "    pushlit         \"\"\n".
                            "    sprint\n".
                            "EndSub\n".
                            "\n");
};

#!/usr/bin/perl -w
#
#  c2plugin: ls
#
use strict;
use c2systest;

# Test normal invocation.
# A: 'c2plugin ls'
# E: plugins in long form, alphabetical
test 'plugin/03_ls/normal', sub {
    my $setup = shift;
    test_ls($setup, ['ls'], ["3 plugins installed.",
                             "--------",
                             "Plugin 'A': A",
                             "",
                             "info a",
                             "--------",
                             "Plugin 'B': B",
                             "",
                             "info b",
                             "--------",
                             "Plugin 'C': C",
                             "",
                             "info c",
                             ""]);
};

# Test short format.
# A: 'c2plugin ls -b'
# E: plugins in short form, alphabetical
test 'plugin/03_ls/b', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-b'], ["A", "B", "C", ""]);
};

# Test short format.
# A: 'c2plugin ls -l -b'
# E: plugins in short form, alphabetical. '-b' cancels '-l'.
test 'plugin/03_ls/lb', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-l', '-b'], ["A", "B", "C", ""]);
};

# Test short format, load order
# A: 'c2plugin ls -b -o' (variants)
# E: plugins in short form, load order.
# The resulting order B>C>A is not entirely implied by dependencies; B>A>C would also be a valid order.
# However, the implementation of loading leaf nodes first will always produce B>C>A.
test 'plugin/03_ls/bo/1', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-b', '-o'], ["B", "C", "A", ""]);
};
test 'plugin/03_ls/bo/2', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-bo'], ["B", "C", "A", ""]);
};
test 'plugin/03_ls/bo/3', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-o', '-b'], ["B", "C", "A", ""]);
};
test 'plugin/03_ls/bo/4', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-ob'], ["B", "C", "A", ""]);
};
test 'plugin/03_ls/bo/5', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-lob'], ["B", "C", "A", ""]);
};

# Test normal invocation.
# A: 'c2plugin ls -l'
# E: plugins in long form, alphabetical
test 'plugin/03_ls/l', sub {
    my $setup = shift;
    test_ls($setup, ['ls', '-l'], ["3 plugins installed.",
                                   "--------",
                                   "Plugin 'A': A",
                                   "",
                                   "info a",
                                   "--------",
                                   "Plugin 'B': B",
                                   "",
                                   "info b",
                                   "--------",
                                   "Plugin 'C': C",
                                   "",
                                   "info c",
                                   "",
                                   "Files (in '<root>/c'):",
                                   "  x.txt",
                                   ""]);
};


##
##  Canned test
##
sub test_ls {
    my ($setup, $command, $result) = @_;
    my $home = setup_add_home($setup);

    # Profile
    mkdir "$home/.pcc2", 0777 or die;

    # Plugin directory
    my $plug_root = "$home/.pcc2/plugins";
    mkdir $plug_root, 0777 or die;

    # Plugins
    file_put("$plug_root/a.c2p", "description = info a\nrequires = b\n");
    file_put("$plug_root/b.c2p", "description = info b\n");
    file_put("$plug_root/c.c2p", "description = info c\nfile = x.txt");

    # Test
    {
        my $sh = shell_new($setup, 'plugin');
        shell_add_args($sh, @$command);
        my $output = shell_call($sh);
        $output =~ s/\Q$plug_root/<root>/g;
        assert_equals $output, join("\n", @$result);
    }
}

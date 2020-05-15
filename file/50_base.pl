#!/usr/bin/perl -w
#
#  File: FileBase
#
#  Synced with TestServerFileFileBase, 20170923.
#  Fails with c2file-classic.
#
use strict;
use c2systest;

# TestServerFileFileBase::testSimple: Some simple tests.
test 'file/50_base/simple', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdir d));
    conn_call($fc, qw(mkdir d/sd));
    conn_call($fc, qw(put d/f content...));
    assert_equals conn_call($fc, qw(get d/f)), 'content...';

    my %i = conn_call_list($fc, qw(stat d));
    assert_equals $i{type}, 'dir';

    %i = conn_call_list($fc, qw(stat d/f));
    assert_equals $i{type}, 'file';
    assert_equals $i{size}, 10;

    assert_throws sub{ conn_call($fc, qw(mkdir d)) }, 409;
    assert_throws sub{ conn_call($fc, qw(mkdir d/f)) }, 409;
    assert_throws sub{ conn_call($fc, qw(put d/sd xx)) }, 409;
};

# TestServerFileFileBase::testCreateDirectory: Test createDirectory variants.
test 'file/50_base/mkdir', sub {
    my $fc = prepare(@_);

    # Create a file in root
    conn_call($fc, 'put', 'f', '');

    # Admin context: create directories
    # - success case
    conn_call($fc, qw(mkdiras u 1001));
    conn_call($fc, qw(mkdiras w 1002));
    conn_call($fc, qw(mkdir u/sub));

    # - failure case: missing user name
    assert_throws sub{ conn_call($fc, 'mkdiras', 'v', '') }, 400;

    # - failure case: already exists
    assert_throws sub{ conn_call($fc, 'mkdiras', 'u', '1001') }, 409;
    assert_throws sub{ conn_call($fc, 'mkdir', 'u')           }, 409;
    assert_throws sub{ conn_call($fc, 'mkdir', 'f')           }, 409;

    # - failure case: bad file names
    assert_throws sub{ conn_call($fc, 'mkdir', '')            }, 400;
    assert_throws sub{ conn_call($fc, 'mkdir', '/a')          }, 400;
    assert_throws sub{ conn_call($fc, 'mkdir', 'u//a')        }, 400;
    assert_throws sub{ conn_call($fc, 'mkdir', 'u/a:b')       }, 400;
    assert_throws sub{ conn_call($fc, 'mkdir', 'u/a\b')       }, 400;
    assert_throws sub{ conn_call($fc, 'mkdir', 'u/.dot')      }, 400;
    assert_throws sub{ conn_call($fc, 'mkdir', "u/a\0b")      }, 400;

    # User context
    conn_call($fc, qw(user 1001));

    # - success case
    conn_call($fc, qw(mkdir u/sub2));

    # - failure case: missing permissions
    assert_throws sub{ conn_call($fc, 'mkdiras', 'u/sub3', '1001') }, 403;
    assert_throws sub{ conn_call($fc, 'mkdir', 'v')                }, 403;
    assert_throws sub{ conn_call($fc, 'mkdir', 'w/x')              }, 403;

    # - failure case: already exists (but also missing permissions), so reports missing permissions
    assert_throws sub{ conn_call($fc, 'mkdir', 'u')                }, 403;
    assert_throws sub{ conn_call($fc, 'mkdir', 'f')                }, 403;

    # - failure case: already exists
    assert_throws sub{ conn_call($fc, 'mkdir', 'u/sub')            }, 409;
};

# TestServerFileFileBase::testGet: Test getFile() and copyFile().
test 'file/50_base/get', sub {
    my $fc = prepare(@_);

    # Create test setup
    conn_call($fc, qw(mkdiras u1 1001));
    conn_call($fc, qw(mkdir u1/sub));
    conn_call($fc, qw(put u1/f u1-f));
    conn_call($fc, qw(put u1/sub/f u1-sub-f));

    conn_call($fc, qw(mkdiras u2 1002));
    conn_call($fc, qw(put u2/f u2-f));

    conn_call($fc, qw(setperm u2 1003 r));
    conn_call($fc, qw(setperm u2 1004 l));

    conn_call($fc, qw(mkdir tmp));
    conn_call($fc, qw(setperm tmp * w));

    # Some file name stuff
    assert_throws sub{ conn_call($fc, qw(get /)) }, 400;
    assert_throws sub{ conn_call($fc, qw(get u1//a)) }, 400;
    assert_throws sub{ conn_call($fc, qw(get u1/x:y/a)) }, 400;
    assert_throws sub{ conn_call($fc, qw(get u1/x:y)) }, 400;
    assert_throws sub{ conn_call($fc, qw(get u1//)) }, 400;

    # User 1
    # - get
    conn_call($fc, qw(user 1001));
    assert_throws sub{ conn_call($fc, qw(get u1)) }, 403;                   # access a directory we can read
    assert_throws sub{ conn_call($fc, qw(get u1/g)) }, 404;                 # access nonexistant file in a directory we can read
    assert_equals conn_call($fc, qw(get u1/f)), "u1-f";                     # ok
    assert_equals conn_call($fc, qw(get u1/sub/f)), "u1-sub-f";             # ok
    assert_throws sub{ conn_call($fc, qw(get u2/f)) }, 403;                 # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u2/g)) }, 403;                 # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u2/g/g)) }, 403;               # access nonexistant file in a directory we cannot read

    # - cp
    assert_throws sub{ conn_call($fc, qw(cp u1 tmp/x1)) }, 403;             # access a directory we can read
    assert_throws sub{ conn_call($fc, qw(cp u1/g tmp/x)) }, 404;            # access nonexistant file in a directory we can read
    conn_call($fc, qw(cp u1/f tmp/x));                                      # ok
    conn_call($fc, qw(cp u1/sub/f tmp/x));                                  # ok
    assert_throws sub{ conn_call($fc, qw(cp u2/f tmp/x)) }, 403;            # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u2/g tmp/x)) }, 403;            # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u2/g/g tmp/x)) }, 403;          # access nonexistant file in a directory we cannot read

    # User 2
    # - get
    conn_call($fc, qw(user 1002));
    assert_throws sub{ conn_call($fc, qw(get u1)) }, 403;                   # access a directory
    assert_throws sub{ conn_call($fc, qw(get u1/g)) }, 403;                 # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u1/f)) }, 403;                 # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u1/sub/f)) }, 403;             # ditto
    assert_equals conn_call($fc, qw(get u2/f)), "u2-f";                     # ok
    assert_throws sub{ conn_call($fc, qw(get u2/g)) }, 404;                 # access nonexistant file in a directory we can read
    assert_throws sub{ conn_call($fc, qw(get u2/g/g)) }, 404;               # access nonexistant file in a directory we can read

    # - cp
    assert_throws sub{ conn_call($fc, qw(cp u1 tmp/x)) }, 403;              # access a directory
    assert_throws sub{ conn_call($fc, qw(cp u1/g tmp/x)) }, 403;            # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u1/f tmp/x)) }, 403;            # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u1/sub/f tmp/x)) }, 403;        # ditto
    conn_call($fc, qw(cp u2/f tmp/x));                                      # ok
    assert_throws sub{ conn_call($fc, qw(cp u2/g tmp/x)) }, 404;            # access nonexistant file in a directory we can read
    assert_throws sub{ conn_call($fc, qw(cp u2/g/g tmp/x)) }, 404;          # access nonexistant file in a directory we can read

    # User 3
    # - get
    conn_call($fc, qw(user 1003));
    assert_throws sub{ conn_call($fc, qw(get u1)) }, 403;                   # access a directory
    assert_throws sub{ conn_call($fc, qw(get u1/g)) }, 403;                 # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u1/f)) }, 403;                 # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u1/sub/f)) }, 403;             # ditto
    assert_equals conn_call($fc, qw(get u2/f)), "u2-f";                     # ok, user got explicit permissions to read
    assert_throws sub{ conn_call($fc, qw(get u2/g)) }, 403;                 # user did not get permissions to read the directory, so this is 403
    assert_throws sub{ conn_call($fc, qw(get u2/g/g)) }, 403;               # access nonexistant file in a directory we cannot read

    # - cp
    assert_throws sub{ conn_call($fc, qw(cp u1 tmp/x)) }, 403;              # access a directory
    assert_throws sub{ conn_call($fc, qw(cp u1/g tmp/x)) }, 403;            # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u1/f tmp/x)) }, 403;            # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u1/sub/f tmp/x)) }, 403;        # ditto
    conn_call($fc, qw(cp u2/f tmp/x));                                      # ok, user got explicit permissions to read
    assert_throws sub{ conn_call($fc, qw(cp u2/g tmp/x)) }, 403;            # user did not get permissions to read the directory, so this is 403

    # User 4
    # - get
    conn_call($fc, qw(user 1004));
    assert_throws sub{ conn_call($fc, qw(get u1)) }, 403;                   # access a directory
    assert_throws sub{ conn_call($fc, qw(get u1/g)) }, 403;                 # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u1/f)) }, 403;                 # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(get u1/sub/f)) }, 403;             # ditto
    assert_throws sub{ conn_call($fc, qw(get u2/f)) }, 403;                 # user got permissions to read the directory but not the file
    assert_throws sub{ conn_call($fc, qw(get u2/g)) }, 404;                 # user got permissions to know that this file does not exist
    assert_throws sub{ conn_call($fc, qw(get u2/g/g)) }, 404;               # user got permissions to know that this file does not exist

    # - cp
    assert_throws sub{ conn_call($fc, qw(cp u1 tmp/x)) }, 403;              # access a directory
    assert_throws sub{ conn_call($fc, qw(cp u1/g tmp/x)) }, 403;            # access nonexistant file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u1/f tmp/x)) }, 403;            # access existing file in a directory we cannot read
    assert_throws sub{ conn_call($fc, qw(cp u1/sub/f tmp/x)) }, 403;        # ditto
    assert_throws sub{ conn_call($fc, qw(cp u2/f tmp/x)) }, 403;            # user got permissions to read the directory but not the file
    assert_throws sub{ conn_call($fc, qw(cp u2/g tmp/x)) }, 404;            # user got permissions to know that this file does not exist
};

# TestServerFileFileBase::testTestFiles: Test testFiles().
test 'file/50_base/test', sub {
    my $fc = prepare(@_);

    # Create test setup
    conn_call($fc, qw(mkdiras u1 1001));
    conn_call($fc, qw(mkdir u1/sub));
    conn_call($fc, qw(put u1/f u1-f));
    conn_call($fc, qw(put u1/sub/f u1-sub-f));

    conn_call($fc, qw(mkdiras u2 1002));
    conn_call($fc, qw(put u2/f u2-f));

    conn_call($fc, qw(setperm u2 1003 r));
    conn_call($fc, qw(setperm u2 1004 l));

    my @FILE_NAMES = qw(u1 u1/g u1/f u1/sub/f u2/f u2/g u2/g/g);

    # Empty
    my @r = conn_call_list($fc, 'ftest');
    assert_equals scalar(@r), 0;

    # Root
    @r = conn_call_list($fc, 'ftest', @FILE_NAMES);
    assert_equals join(',', @r), '0,0,1,1,1,0,0';

    # User 1
    conn_call($fc, qw(user 1001));
    @r = conn_call_list($fc, 'ftest', @FILE_NAMES);
    assert_equals join(',', @r), '0,0,1,1,0,0,0';

    # User 2
    conn_call($fc, qw(user 1002));
    @r = conn_call_list($fc, 'ftest', @FILE_NAMES);
    assert_equals join(',', @r), '0,0,0,0,1,0,0';

    # User 3
    conn_call($fc, qw(user 1003));
    @r = conn_call_list($fc, 'ftest', @FILE_NAMES);
    assert_equals join(',', @r), '0,0,0,0,1,0,0';

    # User 4
    conn_call($fc, qw(user 1004));
    @r = conn_call_list($fc, 'ftest', @FILE_NAMES);
    assert_equals join(',', @r), '0,0,0,0,0,0,0';
};

# TestServerFileFileBase::testProperty: Test getDirectoryProperty(), setDirectoryProperty().
test 'file/50_base/property', sub {
    my $fc = prepare(@_);
    conn_call($fc, qw(mkdir u));

    # Set and get properties
    conn_call($fc, qw(propset u name foo));
    conn_call($fc, qw(propset u count 3));
    conn_call($fc, qw(propset u a e=mc2));
    assert_equals conn_call($fc, qw(propget u name)), 'foo';
    assert_equals conn_call($fc, qw(propget u count)), '3';

    # Error cases
    # - not found
    assert_throws sub{ conn_call($fc, qw(propset v x y)) }, 404;
    assert_throws sub{ conn_call($fc, qw(propset u/v x y)) }, 404;

    # - bad file name
    assert_throws sub{ conn_call($fc, qw(propset u/ x y)) }, 400;
    assert_throws sub{ conn_call($fc, qw(propset a:b x y)) }, 400;
    assert_throws sub{ conn_call($fc, qw(propset u/a:b x y)) }, 400;

    # - bad property name
    assert_throws sub{ conn_call($fc, qw(propset u a=b y)) }, 400;
    assert_throws sub{ conn_call($fc, qw(propset u =b y)) }, 400;
    assert_throws sub{ conn_call($fc, qw(propset u a= y)) }, 400;
    assert_throws sub{ conn_call($fc, 'propset', 'u', "a\nb", 'y') }, 400;

    # - bad property value
    assert_throws sub{ conn_call($fc, 'propset', 'u', 'a', "y\n") }, 400;

    # Forget & reload
    conn_call($fc, qw(forget u));
    assert_equals conn_call($fc, qw(propget u name)), 'foo';
    assert_equals conn_call($fc, qw(propget u count)), '3';
    assert_equals conn_call($fc, qw(propget u a)), 'e=mc2';
};

# TestServerFileFileBase::testPropertyPermissions: Test getDirectoryProperty(), setDirectoryProperty() vs. permissions.
test 'file/50_base/property/perm', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdir writable));
    conn_call($fc, qw(mkdir readable));
    conn_call($fc, qw(mkdir both));
    conn_call($fc, qw(mkdir none));
    conn_call($fc, qw(mkdir none/readable));
    conn_call($fc, qw(mkdir none/writable));
    conn_call($fc, qw(mkdir none/none));
    conn_call($fc, qw(mkdir listable));

    conn_call($fc, qw(setperm writable 1001 w));
    conn_call($fc, qw(setperm readable 1001 r));
    conn_call($fc, qw(setperm both 1001 rw));
    conn_call($fc, qw(setperm none/readable 1001 r));
    conn_call($fc, qw(setperm none/writable 1001 w));
    conn_call($fc, qw(setperm listable 1001 l));

    conn_call($fc, qw(propset writable p w));
    conn_call($fc, qw(propset readable p r));
    conn_call($fc, qw(propset both p b));
    conn_call($fc, qw(propset none p n));
    conn_call($fc, qw(propset none/readable p nr));
    conn_call($fc, qw(propset none/writable p nw));
    conn_call($fc, qw(propset none/none p nn));
    conn_call($fc, qw(propset listable p l));

    # Test reading in user context
    conn_call($fc, qw(user 1001));
    assert_throws sub{ conn_call($fc, qw(propget writable p)) },           403;
    assert_equals      conn_call($fc, qw(propget readable p)),             'r';
    assert_equals      conn_call($fc, qw(propget both p)),                 'b';
    assert_throws sub{ conn_call($fc, qw(propget none p)) },               403;
    assert_equals      conn_call($fc, qw(propget none/readable p)),        'nr';
    assert_throws sub{ conn_call($fc, qw(propget none/writable p)) },      403;
    assert_throws sub{ conn_call($fc, qw(propget none/none p)) },          403;
    assert_throws sub{ conn_call($fc, qw(propget none/missing p)) },       403;
    assert_throws sub{ conn_call($fc, qw(propget listable p)) },           403;
    assert_throws sub{ conn_call($fc, qw(propget readable/missing p)) },   403;
    assert_throws sub{ conn_call($fc, qw(propget listable/missing p)) },   404;

    # Test writing in user context [bug #338]
    conn_call($fc, qw(user 1001));
    conn_call($fc, qw(propset writable p v));
    assert_throws sub{ conn_call($fc, qw(propset readable p v)) },         403;
    conn_call($fc, qw(propset both p v));
    assert_throws sub{ conn_call($fc, qw(propset none p v)) },             403;
    assert_throws sub{ conn_call($fc, qw(propset none/readable p v)) },    403;
    conn_call($fc, qw(propset none/writable p v));
    assert_throws sub{ conn_call($fc, qw(propset none/none p v)) },        403;
    assert_throws sub{ conn_call($fc, qw(propset none/missing p v)) },     403;
    assert_throws sub{ conn_call($fc, qw(propset listable p v)) },         403;
    assert_throws sub{ conn_call($fc, qw(propset readable/missing p v)) }, 403;
    assert_throws sub{ conn_call($fc, qw(propset listable/missing p v)) }, 404;
};

# TestServerFileFileBase::testPropertyFile: Test property access vs. file
test 'file/50_base/property/file', sub {
    my $fc = prepare(@_);
    conn_call($fc, qw(put f c));
    conn_call($fc, qw(mkdir d));
    conn_call($fc, qw(put d/ff cc));

    assert_throws sub{ conn_call($fc, qw(propget f p)) }, 405;
    assert_throws sub{ conn_call($fc, qw(propget dd/ff p)) }, 404;
    assert_throws sub{ conn_call($fc, qw(propset f p v)) }, 405;
    assert_throws sub{ conn_call($fc, qw(propset dd/ff p v)) }, 404;
};

# TestServerFileFileBase::testCreateDirectoryTree: Test createDirectoryTree.
test 'file/50_base/mkdirtree', sub {
    my $fc = prepare(@_);

    # Success case
    conn_call($fc, qw(mkdirhier 0/a/b/c/d/e/f/g));

    # Repeating is ok, also with shorter and longer path
    conn_call($fc, qw(mkdirhier 0/a/b/c/d/e/f/g));
    conn_call($fc, qw(mkdirhier 0/a/b/c/d/e));
    conn_call($fc, qw(mkdirhier 0/a/b/c/d/e/f/g/h/i));

    # Attempt to overwrite a file
    # FIXME: 409 should only be produced if we have read access!
    conn_call($fc, qw(put 1 1));
    assert_throws sub{ conn_call($fc, qw(mkdirhier 1/a/b/c/d/e)) }, 409;

    # Attempt to overwrite a nested file
    conn_call($fc, qw(mkdirhier 2/a/b/c/d));
    conn_call($fc, qw(put 2/a/b/c/d/e 2));
    assert_throws sub{ conn_call($fc, qw(mkdirhier 2/a/b/c/d/e/f/g/h)) }, 409;

    # Attempt to create without write permissions
    conn_call($fc, qw(mkdir 3));
    conn_call($fc, qw(mkdir 4));
    conn_call($fc, qw(setperm 3 1009 r));
    conn_call($fc, qw(setperm 4 1009 w));
    conn_call($fc, qw(user 1009));
    assert_throws sub{ conn_call($fc, qw(mkdirhier 3/a/b)) }, 403;
    conn_call($fc, qw(mkdirhier 4/a));
};

# TestServerFileFileBase::testStat: Test getFileInformation().
test 'file/50_base/stat', sub {
    my $fc = prepare(@_);

    # Test setup
    conn_call($fc, qw(mkdir writable));
    conn_call($fc, qw(mkdir readable));
    conn_call($fc, qw(mkdir both));
    conn_call($fc, qw(mkdir none));
    conn_call($fc, qw(mkdir listable));

    conn_call($fc, qw(setperm writable 1001 w));
    conn_call($fc, qw(setperm readable 1001 r));
    conn_call($fc, qw(setperm both 1001 rw));
    conn_call($fc, qw(setperm listable 1001 l));

    conn_call($fc, qw(put writable/f ww));
    conn_call($fc, qw(put readable/f r));
    conn_call($fc, qw(put both/f), "");
    conn_call($fc, qw(put none/f), "");
    conn_call($fc, qw(put listable/f), "");

    # Some generic tests
    # - invalid file names
    assert_throws sub{ conn_call($fc, "stat", "") }, 400;
    assert_throws sub{ conn_call($fc, "stat", "/") }, 400;
    assert_throws sub{ conn_call($fc, "stat", "readable/") }, 400;
    assert_throws sub{ conn_call($fc, "stat", "/x") }, 400;
    assert_throws sub{ conn_call($fc, "stat", "a:b") }, 400;
    assert_throws sub{ conn_call($fc, "stat", "readable/a:b") }, 400;

    # - non existant
    assert_throws sub{ conn_call($fc, "stat", "foo") }, 404;
    assert_throws sub{ conn_call($fc, "stat", "readable/foo") }, 404;

    # - Content
    my %i;
    %i = conn_call_list($fc, qw(stat writable));
    assert_equals $i{type}, 'dir';
    assert_equals $i{visibility}, 1;                                  # 1 because it has some permissions

    %i = conn_call_list($fc, qw(stat none));
    assert_equals $i{type}, 'dir';
    assert_equals $i{visibility}, 0;

    %i = conn_call_list($fc, qw(stat readable/f));
    assert_equals $i{type}, 'file';
    assert_equals $i{size}, 1;

    # Test as user 1001
    conn_call($fc, qw(user 1001));
    assert_throws sub{ conn_call($fc, "stat", "writable") }, 403;
    assert_throws sub{ conn_call($fc, "stat", "writable/f") }, 403;
    assert_throws sub{ conn_call($fc, "stat", "readable") }, 403;
    assert_throws sub{ conn_call($fc, "stat", "readable/f") }, 403;  # FIXME: should this be allowed?
    assert_throws sub{ conn_call($fc, "stat", "readable/foo") }, 403;
    assert_throws sub{ conn_call($fc, "stat", "both") }, 403;
    assert_throws sub{ conn_call($fc, "stat", "both/f") }, 403;
    assert_throws sub{ conn_call($fc, "stat", "none") }, 403;
    assert_throws sub{ conn_call($fc, "stat", "none/f") }, 403;

    %i = conn_call_list($fc, "stat", "listable");
    assert_equals $i{type}, 'dir';

    %i = conn_call_list($fc, qw(stat listable/f));
    assert_equals $i{type}, 'file';
    assert_equals $i{size}, 0;
    assert !exists $i{visibility};

    assert_throws sub{ conn_call($fc, "stat", "listable/foo") }, 404;
};

# TestServerFileFileBase::testGetDirPermission: Test getDirectoryPermission().
test 'file/50_base/lsperm', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdir root));
    conn_call($fc, qw(mkdiras normal 1001));
    conn_call($fc, qw(mkdiras accessible 1001));
    conn_call($fc, qw(setperm normal 1002 r));
    conn_call($fc, qw(setperm accessible 1002 a));
    conn_call($fc, 'put', 'normal/f', '');
    conn_call($fc, 'put', 'accessible/f', '');

    # Test as root
    assert_throws sub{ conn_call_list($fc, qw(lsperm bad)) }, 404;

    my %i = conn_call_list($fc, qw(lsperm root));
    assert_equals $i{owner}, '';
    assert_equals scalar(@{$i{perms}}), 0;

    %i = conn_call_list($fc, qw(lsperm normal));
    assert_equals $i{owner}, '1001';
    assert_equals scalar(@{$i{perms}}), 1;
    my %u = @{$i{perms}[0]};
    assert_equals $u{user}, '1002';
    assert_equals $u{perms}, 'r';

    %i = conn_call_list($fc, qw(lsperm accessible));
    assert_equals $i{owner}, '1001';
    assert_equals scalar(@{$i{perms}}), 1;
    %u = @{$i{perms}[0]};
    assert_equals $u{user}, '1002';
    assert_equals $u{perms}, 'a';

    # Test as owner
    conn_call($fc, qw(user 1001));
    assert_throws sub{ conn_call_list($fc, qw(lsperm bad)) }, 403;
    assert_throws sub{ conn_call_list($fc, qw(lsperm root)) }, 403;

    %i = conn_call_list($fc, qw(lsperm normal));
    assert_equals $i{owner}, '1001';
    assert_equals scalar(@{$i{perms}}), 1;
    %u = @{$i{perms}[0]};
    assert_equals $u{user}, '1002';
    assert_equals $u{perms}, 'r';

    %i = conn_call_list($fc, qw(lsperm accessible));
    assert_equals $i{owner}, '1001';
    assert_equals scalar(@{$i{perms}}), 1;
    %u = @{$i{perms}[0]};
    assert_equals $u{user}, '1002';
    assert_equals $u{perms}, 'a';

    # Test as other
    conn_call($fc, qw(user 1002));
    assert_throws sub{ conn_call_list($fc, qw(lsperm bad)) }, 403;
    assert_throws sub{ conn_call_list($fc, qw(lsperm root)) }, 403;
    assert_throws sub{ conn_call_list($fc, qw(lsperm noraml)) }, 403;

    %i = conn_call_list($fc, qw(lsperm accessible));
    assert_equals $i{owner}, '1001';
    assert_equals scalar(@{$i{perms}}), 1;
    %u = @{$i{perms}[0]};
    assert_equals $u{user}, '1002';
    assert_equals $u{perms}, 'a';
};

# TestServerFileFileBase::testGetDirContent: Test getDirectoryContent.
test 'file/50_base/ls', sub {
    my $fc = prepare(@_);

    # Setup
    foreach (qw(writable readable both none listable)) {
        conn_call($fc, 'mkdir', $_);
    }
    conn_call($fc, qw(setperm writable 1001 w));
    conn_call($fc, qw(setperm readable 1001 r));
    conn_call($fc, qw(setperm both 1001 rw));
    conn_call($fc, qw(setperm listable 1001 l));

    conn_call($fc, 'put', 'writable/f', 'ww');
    conn_call($fc, 'put', 'readable/f', 'r');
    conn_call($fc, 'put', 'both/f', '');
    conn_call($fc, 'put', 'none/f', '');
    conn_call($fc, 'put', 'listable/f', '');

    # Some generic tests
    # - invalid file names
    assert_throws sub{ conn_call($fc, 'ls', '') }, 400;
    assert_throws sub{ conn_call($fc, 'ls', '/') }, 400;
    assert_throws sub{ conn_call($fc, 'ls', 'readable/') }, 400;
    assert_throws sub{ conn_call($fc, 'ls', '/x') }, 400;
    assert_throws sub{ conn_call($fc, 'ls', 'a:b') }, 400;
    assert_throws sub{ conn_call($fc, 'ls', 'readable/a:b') }, 400;

    # - non existant
    assert_throws sub{ conn_call($fc, 'ls', 'foo') }, 404;
    assert_throws sub{ conn_call($fc, 'ls', 'readable/foo') }, 404;
    assert_throws sub{ conn_call($fc, 'ls', 'readable/f') }, 405;

    # - Content
    my @result = conn_call_list($fc, 'ls', 'writable');
    assert_equals scalar(@result), 2;
    assert_equals $result[0], 'f';
    my %u = @{$result[1]};
    assert_equals $u{type}, 'file';
    assert_equals $u{size}, 2;

    # Test as user 1001
    conn_call($fc, qw(user 1001));

    assert_throws sub{ conn_call($fc, 'ls', 'writable') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'writable/f') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'readable') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'readable/f') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'readable/foo') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'both') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'both/f') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'none') }, 403;
    assert_throws sub{ conn_call($fc, 'ls', 'none/f') }, 403;

    # - Content request works
    conn_call_list($fc, 'ls', 'listable');

    # - Errors
    assert_throws sub{ conn_call($fc, 'ls', 'listable/foo') }, 404;
    assert_throws sub{ conn_call($fc, 'ls', 'listable/f') }, 405;
};

# TestServerFileFileBase::testGetDirContent2: Test getDirectoryContent, 2nd round.
test 'file/50_base/ls2', sub {
    my $fc = prepare(@_);

    # Test setup
    conn_call($fc, qw(mkdirhier a/b/c/d));
    conn_call($fc, qw(mkdir a/b/e));
    conn_call($fc, 'put', 'a/b/f', 'hi!');

    # Why not....
    conn_call($fc, qw(forget a));

    # Read content
    my @result = conn_call_list($fc, 'ls', 'a/b');
    assert_equals scalar(@result), 6;

    my %result = @result;

    assert $result{f};
    my %u = @{$result{f}};
    assert_equals $u{type}, 'file';
    assert_equals $u{size}, 3;

    assert $result{c};
    %u = @{$result{c}};
    assert_equals $u{type}, 'dir';
    assert_equals $u{visibility}, 0;

    assert $result{e};
    %u = @{$result{e}};
    assert_equals $u{type}, 'dir';
    assert_equals $u{visibility}, 0;
};

# TestServerFileFileBase::testRemove: Test removeFile().
test 'file/50_base/rm', sub {
    my $fc = prepare(@_);

    # Create stuff
    conn_call($fc, qw(mkdir readable));
    conn_call($fc, qw(mkdir listable));
    conn_call($fc, qw(mkdir writable));
    conn_call($fc, qw(setperm writable 1009 w));
    conn_call($fc, qw(setperm listable 1009 l));
    conn_call($fc, qw(setperm readable 1009 r));
    conn_call($fc, 'put', 'readable/f', '');
    conn_call($fc, 'put', 'writable/f', '');
    conn_call($fc, 'put', 'listable/f', '');
    conn_call($fc, qw(mkdir readable/d));
    conn_call($fc, qw(mkdir writable/d));
    conn_call($fc, qw(mkdir listable/d));

    # Remove as user
    conn_call($fc, qw(user 1009));
    assert_throws sub{ conn_call($fc, qw(rm readable/f)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rm readable/d)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rm readable/nx)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rm readable/nx/nx)) }, 403;

    conn_call($fc, qw(rm writable/f));
    conn_call($fc, qw(rm writable/d));
    assert_throws sub{ conn_call($fc, qw(rm writable/nx)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rm writable/nx/nx)) }, 403;

    assert_throws sub{ conn_call($fc, qw(rm listable/f)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rm listable/d)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rm listable/nx)) }, 404;

    assert_throws sub{ conn_call($fc, qw(rm listable/nx/nx)) }, 404;
};

# TestServerFileFileBase::testRemoveNonemptyDir: Test removal of non-empty directory.
test 'file/50_base/rm/nonemptydir', sub {
    my $fc = prepare(@_);

    # Create stuff
    conn_call($fc, qw(mkdir a));
    conn_call($fc, qw(mkdir a/b));
    conn_call($fc, 'put', 'a/b/zz', '');

    # Erase
    assert_throws sub{ conn_call($fc, qw(rm a/b)) }, 403;

    conn_call($fc, qw(rm a/b/zz));
    conn_call($fc, qw(rm a/b));
};

# TestServerFileFileBase::testRemoveNonemptyDir2: Test removal of non-empty directory, with a permission file.
test 'file/50_base/rm/nonemptydir2', sub {
    # Manually set up so we can access the underlying storage
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'f');
    my $fs = setup_add_app($setup, 'file', 'c2file');
    setup_add_service_config($setup, 'file.basedir', $dir);
    mkdir $dir, 0777 or die "$dir: $!";
    setup_start($setup);

    my $fc = service_connect_wait($fs);

    # Create stuff
    conn_call($fc, qw(mkdir a));
    conn_call($fc, qw(mkdir a/b));
    conn_call($fc, 'put', 'a/b/zz', '');
    conn_call($fc, qw(setperm a/b 1020 rwl));

    # Verify underlying structure
    assert -d "$dir/a";
    assert -d "$dir/a/b";
    assert -f "$dir/a/b/.c2file";

    # Erase
    assert_throws sub{ conn_call($fc, qw(rm a/b)) }, 403;

    conn_call($fc, qw(rm a/b/zz));
    conn_call($fc, qw(rm a/b));
};

# TestServerFileFileBase::testRemoveNonemptyDir3: Test removal of non-empty directory, with an extra file.
test 'file/50_base/rm/nonemptydir3', sub {
    # Manually set up so we can access the underlying storage
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'f');
    my $fs = setup_add_app($setup, 'file', 'c2file');
    setup_add_service_config($setup, 'file.basedir', $dir);
    mkdir $dir, 0777 or die "$dir: $!";
    setup_start($setup);

    my $fc = service_connect_wait($fs);

    # Create stuff
    conn_call($fc, qw(mkdir a));
    conn_call($fc, qw(mkdir a/b));

    # Verify internal structure
    assert -d "$dir/a";
    assert -d "$dir/a/b";
    file_put("$dir/a/b/.block", "");

    # Verify that a/b appears empty
    my @result = conn_call_list($fc, qw(ls a/b));
    assert_equals scalar(@result), 0;

    # Erase
    # This fails because the ".block" file is not recognized and therefore cannot be removed.
    assert_throws sub{ conn_call($fc, qw(rm a/b)) }, 403;
};

# TestServerFileFileBase::testRemoveTree: Test removal of a directory tree, base case.
test 'file/50_base/rmdir', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdirhier a/b/c/d/e));
    conn_call($fc, qw(mkdirhier a/b/c/x/y));
    conn_call($fc, 'put', 'a/f', '');

    # Some failures
    assert_throws sub{ conn_call($fc, qw(rmdir a/f)) }, 405;
    assert_throws sub{ conn_call($fc, qw(rmdir a/x)) }, 404;

    # Success
    conn_call($fc, qw(rmdir a/b/c/x));
    conn_call($fc, qw(stat a/b/c/d));

    conn_call($fc, qw(rmdir a/b));
    assert_throws sub{ conn_call($fc, qw(stat a/b)) }, 404;
};

# TestServerFileFileBase::testRemoveTree1: Test removal of a directory tree, user case 1.
test 'file/50_base/rmdir/user1', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdirhier a/b/c/d/e));
    conn_call($fc, qw(mkdirhier a/b/c/x/y));
    conn_call($fc, 'put', 'a/b/c/d/e/f', '');

    # User has access to children, but not root
    conn_call($fc, qw(setperm a/b/c/d/e 1001 w));
    conn_call($fc, qw(setperm a/b/c/d 1001 w));
    conn_call($fc, qw(setperm a/b/c/x/y 1001 w));
    conn_call($fc, qw(setperm a/b/c/x 1001 w));

    conn_call($fc, qw(user 1001));
    assert_throws sub{ conn_call($fc, qw(rmdir a/b)) }, 403;

    # Verify it's still there
    conn_call($fc, 'user', '');
    conn_call($fc, 'stat', 'a/b');
};

# TestServerFileFileBase::testRemoveTree2: Test removal of a directory tree, user case 2.
test 'file/50_base/rmdir/user2', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdirhier a/b/c/d/e));
    conn_call($fc, qw(mkdirhier a/b/c/x/y));
    conn_call($fc, 'put', 'a/b/c/d/e/f', '');

    # User has access to root, but not all children
    conn_call($fc, qw(setperm a 1001 w));
    conn_call($fc, qw(setperm a/b 1001 w));
    conn_call($fc, qw(setperm a/b/c 1001 w));
    conn_call($fc, qw(setperm a/b/c/d 1001 w));
    conn_call($fc, qw(setperm a/b/c/d/e 1001 w));
    conn_call($fc, qw(setperm a/b/c/x 1001 w));

    conn_call($fc, qw(user 1001));
    assert_throws sub{ conn_call($fc, qw(rmdir a/b)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rmdir a/b/c)) }, 403;
    conn_call($fc, qw(rmdir a/b/c/d));

    # Verify it's still there
    conn_call($fc, 'user', '');
    conn_call($fc, 'stat', 'a/b');
};

# TestServerFileFileBase::testRemoveTree3: Test removal of a directory tree, user case 3.
test 'file/50_base/rmdir/user3', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdirhier a/b/c/d/e));
    conn_call($fc, qw(mkdirhier a/b/c/x/y));
    conn_call($fc, 'put', 'a/b/c/d/e/f', '');

    # User has full access
    conn_call($fc, qw(setperm a 1001 w));
    conn_call($fc, qw(setperm a/b 1001 w));
    conn_call($fc, qw(setperm a/b/c 1001 w));
    conn_call($fc, qw(setperm a/b/c/d 1001 w));
    conn_call($fc, qw(setperm a/b/c/d/e 1001 w));
    conn_call($fc, qw(setperm a/b/c/x 1001 w));
    conn_call($fc, qw(setperm a/b/c/x/y 1001 w));

    conn_call($fc, qw(user 1001));
    conn_call($fc, qw(rmdir a/b));

    # Verify it's gone
    conn_call($fc, 'user', '');
    assert_throws sub{ conn_call($fc, 'stat', 'a/b') }, 404;
    conn_call($fc, 'stat', 'a');
};

# TestServerFileFileBase::testRemoveTreeFail: Test removal of directory tree, with an extra file.
test 'file/50_base/rmdir/fail', sub {
    # Manually set up so we can access the underlying storage
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'f');
    my $fs = setup_add_app($setup, 'file', 'c2file');
    setup_add_service_config($setup, 'file.basedir', $dir);
    mkdir $dir, 0777 or die "$dir: $!";
    setup_start($setup);

    my $fc = service_connect_wait($fs);

    # Create stuff
    conn_call($fc, qw(mkdirhier a/b/c/d/e));
    conn_call($fc, qw(mkdirhier a/b/x/y/z));

    # Verify internal structure
    assert -d "$dir/a";
    assert -d "$dir/a/b";
    assert -d "$dir/a/b/x";
    file_put("$dir/a/b/x/.block", "");

    # Erase
    # This fails because the ".block" file is not recognized and therefore cannot be removed.
    # Note that the directory might have still be cleared partially here.
    assert_throws sub{ conn_call($fc, qw(rmdir a/b)) }, 403;
};

# TestServerFileFileBase::testRemoveTreePerm: Test removeDirectory(), permission test.
test 'file/50_base/rmdir/perm', sub {
    my $fc = prepare(@_);
    # Create stuff
    conn_call($fc, qw(mkdir readable));
    conn_call($fc, qw(mkdir listable));
    conn_call($fc, qw(mkdir writable));
    conn_call($fc, qw(setperm writable 1009 w));
    conn_call($fc, qw(setperm listable 1009 l));
    conn_call($fc, qw(setperm readable 1009 r));
    conn_call($fc, 'put', 'readable/f', '');
    conn_call($fc, 'put', 'writable/f', '');
    conn_call($fc, 'put', 'listable/f', '');
    conn_call($fc, qw(mkdir readable/d));
    conn_call($fc, qw(mkdir writable/d));
    conn_call($fc, qw(mkdir listable/d));

    # Remove as user
    conn_call($fc, qw(user 1009));
    assert_throws sub{ conn_call($fc, qw(rmdir readable/f)) },  403;
    assert_throws sub{ conn_call($fc, qw(rmdir readable/d)) },  403;
    assert_throws sub{ conn_call($fc, qw(rmdir readable/nx)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rmdir readable/nx/nx)) }, 403;

    assert_throws sub{ conn_call($fc, qw(rmdir writable/f)) },  403;
    # FIXME: the following should probably be permitted.
    # It fails because of missing permissions on 'd', but removeFile(d) would be accepted.
    assert_throws sub{ conn_call($fc, qw(rmdir writable/nx)) }, 403;
    assert_throws sub{ conn_call($fc, qw(rmdir writable/nx/nx)) }, 403;

    assert_throws sub{ conn_call($fc, qw(rmdir listable/f)) },  405;
    assert_throws sub{ conn_call($fc, qw(rmdir listable/d)) },  403;
    assert_throws sub{ conn_call($fc, qw(rmdir listable/nx)) }, 404;
    assert_throws sub{ conn_call($fc, qw(rmdir listable/nx/nx)) }, 404;
};

# TestServerFileFileBase::testUsage: Test getDiskUsage().
test 'file/50_base/usage', sub {
    my $fc = prepare(@_);

    # Create stuff
    conn_call($fc, qw(mkdir readable));
    conn_call($fc, qw(mkdir listable));
    conn_call($fc, qw(mkdir writable));
    conn_call($fc, qw(setperm writable 1009 w));
    conn_call($fc, qw(setperm listable 1009 l));
    conn_call($fc, qw(setperm readable 1009 r));
    conn_call($fc, 'put', 'readable/f', '');
    conn_call($fc, 'put', 'writable/f', 'w');
    conn_call($fc, 'put', 'listable/f', 'x' x 10240);
    conn_call($fc, qw(mkdir readable/d));
    conn_call($fc, qw(mkdir writable/d));
    conn_call($fc, qw(mkdir listable/d));

    # Test as root
    my %u = conn_call_list($fc, qw(usage readable));
    assert_equals $u{files}, 3;               # 1 per directory, 1 per file
    assert_equals $u{kbytes}, 2;              # 1 per directory, 0 for the empty file

    %u = conn_call_list($fc, qw(usage writable));
    assert_equals $u{files}, 3;               # 1 per directory, 1 per file
    assert_equals $u{kbytes}, 3;              # 1 per directory, 1 for the nonempty file

    %u = conn_call_list($fc, qw(usage listable));
    assert_equals $u{files}, 3;               # 1 per directory, 1 per file
    assert_equals $u{kbytes}, 12;             # 1 per directory, 10 for the file file

    assert_throws sub{ conn_call_list($fc, qw(usage nx)) }, 404;
    assert_throws sub{ conn_call_list($fc, qw(usage readable/nx)) }, 404;
    assert_throws sub{ conn_call_list($fc, qw(usage readable/nx/nx)) }, 404;

    assert_throws sub{ conn_call_list($fc, qw(usage readable/f)) }, 405;

    # Test as user
    conn_call($fc, qw(user 1009));
    assert_throws sub{ conn_call_list($fc, qw(usage readable)) }, 403;
    assert_throws sub{ conn_call_list($fc, qw(usage writable)) }, 403;

    %u = conn_call_list($fc, qw(usage listable));
    assert_equals $u{files}, 3;               # 1 per directory, 1 per file
    assert_equals $u{kbytes}, 12;             # 1 per directory, 10 for the file file

    assert_throws sub{ conn_call_list($fc, qw(usage nx)) }, 403;
    assert_throws sub{ conn_call_list($fc, qw(usage readable/nx)) }, 403;
    assert_throws sub{ conn_call_list($fc, qw(usage readable/nx/nx)) }, 403;
    assert_throws sub{ conn_call_list($fc, qw(usage readable/f)) }, 403;

    assert_throws sub{ conn_call_list($fc, qw(usage listable/nx)) }, 404;
    assert_throws sub{ conn_call_list($fc, qw(usage listable/nx/nx)) }, 404;
    assert_throws sub{ conn_call_list($fc, qw(usage listable/f)) }, 405;
};

# TestServerFileFileBase::testPut: Test putFile.
test 'file/50_base/put', sub {
    my $fc = prepare(@_);

    # Create stuff
    conn_call($fc, qw(mkdir readable));
    conn_call($fc, qw(mkdir listable));
    conn_call($fc, qw(mkdir writable));
    conn_call($fc, qw(setperm writable 1009 w));
    conn_call($fc, qw(setperm listable 1009 l));
    conn_call($fc, qw(setperm readable 1009 r));
    conn_call($fc, qw(mkdir readable/d));
    conn_call($fc, qw(mkdir writable/d));
    conn_call($fc, qw(mkdir listable/d));

    # Test as user
    conn_call($fc, qw(user 1009));
    assert_throws sub{ conn_call($fc, qw(put rootfile x)) }, 403;
    assert_throws sub{ conn_call($fc, qw(put readable/f x)) }, 403;
    conn_call($fc, qw(put writable/f x));
    assert_throws sub{ conn_call($fc, qw(put writable/nx/f x)) }, 403;
    assert_throws sub{ conn_call($fc, qw(put listable/f x)) }, 403;
    assert_throws sub{ conn_call($fc, qw(put listable/d/f x)) }, 403;
    assert_throws sub{ conn_call($fc, qw(put listable/nx/f x)) }, 404;

    # Attempt to overwrite a directory
    assert_throws sub{ conn_call($fc, qw(put writable/d x)) }, 409;
};

# TestServerFileFileBase::testLimits: Test limits.
test 'file/50_base/limits', sub {
    # Manually set up so we can access the underlying storage and config
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'f');
    my $fs = setup_add_app($setup, 'file', 'c2file');
    setup_add_service_config($setup, 'file.basedir', $dir);
    setup_add_service_config($setup, 'file.sizelimit', 10);
    mkdir $dir, 0777 or die "$dir: $!";
    setup_start($setup);

    file_put("$dir/ten", 'x' x 10);
    file_put("$dir/eleven", 'x' x 11);

    my $fc = service_connect_wait($fs);

    # get
    conn_call($fc, 'get', 'ten');
    assert_throws sub{ conn_call($fc, 'get', 'eleven') }, 413;

    # put
    conn_call($fc, 'put', 'ten2', 'y' x 10);
    assert_throws sub{ conn_call($fc, 'put', 'eleven2', 'y' x 11) }, 413;

    # copy
    conn_call($fc, 'cp', 'ten', 'ten3');
    assert_throws sub{ conn_call($fc, qw(cp eleven eleven3)) }, 413;
};

# TestServerFileFileBase::testCopy: Test some copyFile() border cases.
test 'file/50_base/copy', sub {
    my $fc = prepare(@_);

    conn_call($fc, qw(mkdir a));
    conn_call($fc, qw(mkdir a/b));
    conn_call($fc, qw(put a/f x));

    # Attempt to overwrite a directory
    assert_throws sub{ conn_call($fc, qw(cp a/f a/b)) }, 409;

    # Copy from nonexistant path
    assert_throws sub{ conn_call($fc, qw(cp a/x/y a/f)) }, 404;

    # Test to copy a directory
    assert_throws sub{ conn_call($fc, qw(cp a/b a/y)) }, 404;
};

# TestServerFileFileBase::testCopyUnderlay: Test copyFile() implemented in underlay.
test 'file/50_base/copy2', sub {
    # CA backend allows underlay copies, so build one.
    my $setup = shift;
    my $fs = setup_add_app($setup, 'file', 'c2file');
    setup_add_service_config($setup, 'file.basedir', 'ca:int:');
    setup_start($setup);

    my $fc = service_connect_wait($fs);

    # Create, copy and verify a file
    # (We cannot sensibly determine from the outside that this actually is an underlay copy.
    # But it can be seen in the coverage report.)
    conn_call($fc, qw(put a content));
    conn_call($fc, qw(cp a b));
    assert_equals conn_call($fc, qw(get b)), 'content';

    my %a = conn_call_list($fc, qw(stat a));
    my %b = conn_call_list($fc, qw(stat b));
    assert_equals $a{size}, 7;
    assert_equals $b{size}, 7;
};


sub prepare {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_start_wait($setup);

    setup_connect_app($setup, 'file');
}

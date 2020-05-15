#!/usr/bin/perl -w
#
#  PCC2/c2ng/PlanetsCentral System Test
#
#  Error handling:
#    Use....             if the reason is...
#    test_failure(x)     an error in the test setup (e.g. invalid function call sequence)
#    assert_failure(x)   an error in the system-under-test
#    die x               an error in an unknown or other area (e.g. OS limit exceeded)
#
#  Template for a test:
#    test 'name', sub {
#      my $setup = shift;
#      # test goes here
#    };
#
#  High-level Operation:
#  - create a SETUP object: either by having `test` give you one (preferred), or by using
#    `setup_create` to create a standalone one. SETUP will provide status tracking and a
#    temporary directory. Use the `setup_xxx` functions to interrogate the environment and
#    add configuration and microservices to the setup.
#  - create SERVICE objects: either by having `setup_add_XXX` create one to the setup
#    (preferred) or by using `service_create`. This will allow you to start, connect to,
#    and stop the service.
#  - calling `setup_start` will create the configuration (c2config.txt) implied by the
#    configured setup, and start all services.
#  - create CONNECTION objects by calling one of the `service_connect` methods. This will
#    allow you to talk to the service.
#  - use the `assert` methods to check stuff.
#  - use the `trace` methods to print stuff (normally not needed).
#  - finally, clean up by calling `service_stop`, `setup_stop`, `setup_destroy`. If you use
#    `test`, this will be done automatically for you.
#
#  It is preferred to use the SETUP object provided by `test`, and manage all microservices
#  through it. This maintains a consistent configuration (c2config.txt, C2CONFIG environment
#  variable).
#
#  Using separately-created SERVICEs is possible, but will require you to manage them and
#  clean them up. If you fail to clean up, their processes will keep hanging around, and
#  prevent further tests from completing by blocking ports.
#

package c2systest;

use strict;
use bytes;
use IO::Socket::INET();
use Time::HiRes('sleep', 'time');


# Magic to just export everything
# (https://stackoverflow.com/questions/732133/how-can-i-export-all-subs-in-a-perl-package)
sub import {
    no strict 'refs';
    my $caller = caller;
    while (my ($name, $symbol) = each %c2systest::) {
        next if      $name eq 'BEGIN';   # don't export BEGIN blocks
        next if      $name eq 'import';  # don't export this sub
        next if      $name =~ /^_/;      # don't export privates
        next unless *{$symbol}{CODE};    # export subs only

        *{$caller.'::'.$name } = \*{$symbol};
    }
}


##
##  Command line
##

my $_cmdl_args;
my $_log_level = 0;
my $_log_color = -t STDOUT;
my $_debug = 0;
my $_test_only = 0;
my $_test_current = 0;
my $_keep_temps = 0;

# cmdl_parse(): Parse command line.
sub cmdl_parse {
    if (!$_cmdl_args) {
        $_cmdl_args = {
            config => {},
            config_file => [],
            path_prefix => ''
        };
        if ($0 =~ m|^(.*/)|) {
            $_cmdl_args->{path_prefix} = $1;
        }
        foreach (@ARGV) {
            if (/^--?help$/) {
                print "Usage: $0 [-opts]

  -Dkey=value        Set system configuration
  --config=file      Set system configuration file name
  --[no-]colors      Colored output
  -v / -q            Add/remove verbosity
  --debug            Internal debug mode
  --only=N           Run only Nth test case
  --keep-temps=N     Keep temporary directories\n";
                exit 0;
            } elsif (/^-D(.*?)=(.*)/) {
                $_cmdl_args->{config}{lc($1)} = $2;
            } elsif (/^--?config=(.*)/) {
                push @{$_cmdl_args->{config_file}}, $1;
            } elsif (/^--?color$/) {
                $_log_color = 1;
            } elsif (/^--?no-?color$/) {
                $_log_color = 0;
            } elsif (/^-(v+)$/) {
                $_log_level += length($1);
            } elsif (/^-v(\d+)$/) {
                $_log_level += $1;
            } elsif (/^-(q+)$/) {
                $_log_level -= length($1);
            } elsif (/^--?debug$/) {
                $_debug = 1;
            } elsif (/^--?only=(\d+)$/) {
                $_test_only = $1;
            } elsif (/^--?keep-temps?$/) {
                $_keep_temps = 1;
            } else {
                die "$0: unknown command-line option '$_'\n";
            }
        }
    }
    push @{$_cmdl_args->{config_file}}, 'system.conf'
        if !@{$_cmdl_args->{config_file}};
    $_cmdl_args;
}

# cmdl_input_file($fn): Name of input file. Given a file name relative to the test file,
# this returns the full file name suitable for open() etc.
# Return: full file name.
sub cmdl_input_file {
    my $file = shift;
    my $cmdl = cmdl_parse();
    return $cmdl->{path_prefix} . $file;
}

##
##  Trace
##
##  Trace levels:
##    0    default (overall test structure)
##    1    programs being run
##    2    output of programs
##    3    creation of test objects
##

# trace($level, @msg): write trace message
sub trace {
    my $level = shift;
    if ($level <= $_log_level) {
        # print "\033[3${level}m", @_, "\033[0m\n";
        print "\t", @_, "\n";
    }
}

# trace_detail(@msg): write a detail
sub trace_detail {
    # xref conn_call
    trace(4, "\t", @_);
}

# trace_creation(@msg): write "object created or destroyed" message
sub trace_creation {
    trace(3, @_);
}

# trace_process(@msg): write "process started" message
sub trace_process {
    trace(1, @_);
}

# trace_test(@msg): write major info message
sub trace_test {
    trace(0, "* ", @_);
}

# trace_is_enabled($lvl): check whether level is enabled
sub trace_is_enabled {
    my $lvl = shift;
    return $lvl <= $_log_level;
}

# trace_color(color, @msg): colorize message (or don't if output is not a tty)
sub trace_color {
    my $color = shift;
    my @result;
    if ($_log_color) {
        @result = ("\033[${color}m", @_, "\033[0m");
    } else {
        @result = @_;
    }
    wantarray ? @result : join('', @result);
}

# test_failure($msg): die with a message that indicates the test is wrong (i.e. the error is in the test,
# not in the system-under-test or the environment). Use, for example, if parameter validation fails.
sub test_failure {
    my $msg = shift;
    _print_backtrace($msg, 'Error in test', '35');
    die "Error in test\n";
}

# trace_adjust($delta): adjust trace level (negative: quieter, positive: more verbose).
sub trace_adjust {
    my $delta = shift;
    $_log_level += $delta;
}

##
##  Setup: test setup
##

my $_tmpdir_counter = 0;
my $_port_counter = 11100;        # global to avoid address-reuse problems

# setup_create(opt $name): create a Setup object
# Returns: setup handle
sub setup_create {
    my $name = shift;
    my $config = _setup_load_config();
    if (!defined $name) { $name = caller };
    trace_creation("Creating setup: $name");

    # Pre-command hook
    if (exists $config->{'initcommand'}) {
        my $cmd = $config->{'initcommand'};
        trace_process("Executing: $cmd");
        my $result = system($cmd);
        if ($result != 0) {
            die "Command '$cmd' failed with exit code $result\n";
        }
    }

    # Default service configuration with keys we don't want at defaults
    my $service_config = {
        'user.key' => 'y',
        'smtp.host' => '10.5.5.5',
        'smtp.port' => 11025,
        'smtp.fqdn' => 'local-fqdn',
        'smtp.from' => 'stefan@localhost',
        'www.key' => 'x',
        'www.url' => 'http://pcc/'
    };

    # Create temporary directory
    my $tmpdir = "/tmp/c2sys$$";
    while (!mkdir $tmpdir, 0700) {
        $tmpdir = "/tmp/c2sys$$." . ++$_tmpdir_counter;
    }
    trace_creation("Creating directory: $tmpdir");

    # Set as temporary directory for c2host
    $service_config->{'host.workdir'} = $tmpdir;

    # Create marker file in case directory remains there
    open MARKER, '>', "$tmpdir/.marker" or die "$tmpdir/.marker: $!";
    print MARKER "Test case '$name'\n";
    close MARKER;

    # Create result
    return {
        name => $name,
        system_config => $config,              # System configuration (a hash)
        service_config => $service_config,     # Service configuration (c2config.txt)
        services => [],                        # Services
        tmpdir => $tmpdir,
        counter => 0,
        started => 0
    };
}

# setup_destroy($setup): shut down a Setup object
sub setup_destroy {
    my $setup = shift;
    _setup_verify($setup);
    setup_stop($setup);
    my $tmpdir = $setup->{tmpdir};
    if (defined($tmpdir) && $tmpdir ne '' && $tmpdir ne '/') {
        if ($_keep_temps) {
            trace_test("Keeping directory: $tmpdir");
        } else {
            trace_creation("Removing directory: $tmpdir");
            system "rm", "-rf", $tmpdir;
        }
        $setup->{tmpdir} = undef;
    }
}

# setup_get_system_config($setup, key): return config value
# Returns: value as string, '' if missing
sub setup_get_system_config {
    # Parameters
    my $setup = shift;
    _setup_verify($setup);

    my $key = shift;
    test_failure('Missing $key') if !defined($key);

    # Act
    my $value = setup_get_system_config_raw($setup, $key);
    my $n     = 0;
    1 while ++$n < 100 && $value =~ s|\$\(([^)]+)\)|setup_get_system_config_raw($setup, $1)|eg;
    $value;
}

# setup_get_required_system_config($setup, key): return config value, fail if it does not exist
# Returns: value as string, never ''
sub setup_get_required_system_config {
    my ($setup, $key) = @_;
    my $result = setup_get_system_config($setup, $key);
    if ($result eq '') { die "Configuration key '$key' is missing\n"; }
    $result;
}

# setup_get_system_config_raw($setup, key): return config value but don't expand variables
# Returns: value as string, '' if missing
sub setup_get_system_config_raw {
    # Parameters
    my ($setup, $key) = @_;

    # Verify
    _setup_verify($setup);
    test_failure('Missing $key') if !defined($key);

    # Act
    my $value = $setup->{system_config}{lc($key)};
    defined($value) ? $value : '';
}

# setup_get_tmpfile_name($setup, $name): get name of a file in the temporary directory.
# Returns: file name as string (temporary directory plus $name).
sub setup_get_tmpfile_name {
    my ($setup, $name) = @_;
    _setup_verify($setup);
    test_failure('Missing $name') if !defined $name;
    test_failure('Setup already destroyed') if !defined $setup->{tmpdir};

    return $setup->{tmpdir}.'/'.$name;
}

# setup_allocate_port($setup): returns a newly-allocated port number
# Returns: port number
sub setup_allocate_port {
    my $setup = shift;           # $_port_counter was an instance variable previously
    _setup_verify($setup);
    return ++$_port_counter;
}

# setup_count($setup): increments internal counter and return it.
# Can be used for generating file names etc.
# Returns: counter
sub setup_count {
    my $setup = shift;
    _setup_verify($setup);
    return ++$setup->{count};
}

# setup_add_service_config($setup, key=>value): add service configuration
sub setup_add_service_config {
    my $setup = shift;
    _setup_verify($setup);
    if ($setup->{started}) { test_failure('Cannot modify service config after starting setup') }
    while (@_) {
        my $key = shift;
        my $value = shift;
        $setup->{service_config}{$key} = $value;
        trace_detail("service config $key = $value");
    }
}

# setup_add_db: add database service.
# Returns: service handle
sub setup_add_db {
    my $setup = shift;
    _setup_verify($setup);

    my $port = setup_allocate_port($setup);
    my $host = '127.0.0.1';
    my $binary = setup_get_required_system_config($setup, 'respserver.path');
    my $db;
    if ($binary =~ /respserver/) {
        # Using respserver as database
        $db = service_create('db', $binary, '-multi', "$host:$port");
    } else {
        # Using redis as database
        my $rc = "$setup->{tmpdir}/redis_$port.conf";
        my %config = (daemonize => "no",
                      pidfile => "$setup->{tmpdir}/redis_$port.pid",
                      port => $port,
                      bind => $host,
                      dbfilename => "redis_$port.rdb",
                      dir => $setup->{tmpdir},
                      appendonly => "no");
        open RC, '>', $rc or die "$rc: $!";
        foreach (sort keys %config) {
            print RC "$_ $config{$_}\n";
        }
        close RC;
        $db = service_create('db', $binary, $rc);
    }
    service_set_port($db, $port);
    setup_add_service_config($setup,
                             'redis.host', $host,
                             'redis.port', $port);
    push @{$setup->{services}}, $db;
    $db;
}

# setup_add_app($setup, $inst, $name, opt @args): add application service
#   $inst: instance name (e.g. 'hostfile', 'redis')
#   $name: program name in system config (e.g. 'c2file', 'respserver')
#   @args: optional args (e.g. '-Ihostfile')
# Returns: service handle
sub setup_add_app {
    my $setup = shift;
    my $inst = shift;
    my $name = shift;

    # Verify
    _setup_verify($setup);
    if (!defined $inst)    { test_failure('Missing $inst') }
    if (!defined $name)    { test_failure('Missing $name') }
    if ($setup->{started}) { test_failure('Cannot add application server after starting setup') }

    # Figure out program
    my $prog = setup_get_required_system_config($setup, "$name.path");

    # Set it up
    my $port = setup_allocate_port($setup);
    my $host = '127.0.0.1';
    my $svc = service_create($inst, $prog, @_);
    service_set_port($svc, $port);
    setup_add_service_config($setup,
                             "$inst.host", $host,
                             "$inst.port", $port);
    push @{$setup->{services}}, $svc;
    $svc;
}

# setup_add_talk($setup): add "talk" service
# Returns: service handle
sub setup_add_talk {
    my $setup = shift;
    setup_add_app($setup, 'talk', 'c2talk');
}

# setup_add_nntp($setup): add "nntp" service
# Returns: service handle
sub setup_add_nntp {
    my $setup = shift;
    my $svc = setup_add_app($setup, 'nntp', 'c2nntp');
    service_set_pingable($svc, 0);
    $svc;
}

# setup_add_talk($setup): add "mailout" service
# Returns: service handle
sub setup_add_mailout {
    my $setup = shift;
    my $tx = shift;
    setup_add_app($setup, 'mailout', 'c2mailout', ($tx ? () : ('-notx')));
}

# setup_add_host($setup[, commandline]): add "host" service
# Returns: service handle
sub setup_add_host {
    my $setup = shift;
    setup_add_app($setup, 'host', 'c2host', @_);
}

# setup_add_user($setup[, commandline]): add "user" service
# Returns: service handle
sub setup_add_usermgr {
    my $setup = shift;
    setup_add_app($setup, 'user', 'c2user', @_);
}

# setup_add_router($setup[, commandline]): add "router" service
# You need to configure ROUTER.SERVER (and ROUTER.FILENOTIFY if you don't have a file server).
# Returns: service handle
sub setup_add_router {
    my $setup = shift;
    my $rs = setup_add_app($setup, 'router', 'c2router', @_);
    service_set_pingable($rs, 0);
    $rs;
}

# setup_add_userfile($setup, opt $basedir): add user filer ("file").
# Pass 'auto' as basedir to create one automatically.
# Pass undefined (leave out) basedir to run on internal storage if possible.
# Returns: service handle
sub setup_add_userfile {
    my $setup = shift;
    my $basedir = shift;
    $basedir = _setup_wrap_dir($setup, $basedir, 'ufroot');
    if (!defined($basedir)) {
        # No basedir given means we're using the builtin default (memory file system),
        # and don't expect other microservices to mess with the file space.
        # In particular, this allows c2host-classic to run against c2file-ng, as long
        # as no usecases that access files are involved.
        setup_add_app($setup, 'file', 'c2file', '-Dfile.basedir=int:');
    } else {
        setup_add_service_config($setup, 'file.basedir', $basedir);
        setup_add_app($setup, 'file', 'c2file');
    }
}

# setup_add_hostfile($setup, opt $basedir): add host filer ("hostfile").
# Pass 'auto' as basedir to create one automatically.
# Pass undefined (leave out) basedir to run on internal storage if possible.
# Returns: service handle
sub setup_add_hostfile {
    my $setup = shift;
    my $basedir = shift;
    $basedir = _setup_wrap_dir($setup, $basedir, 'hfroot');
    my $inst_param = _setup_file_is_classic($setup) ? '-Ihostfile' : '--instance=hostfile';
    if (!defined($basedir)) {
        setup_add_app($setup, 'hostfile', 'c2file', $inst_param, '-Dhostfile.basedir=int:');
    } else {
        setup_add_service_config($setup, 'hostfile.basedir', $basedir);
        setup_add_app($setup, 'hostfile', 'c2file', $inst_param);
    }
}

# setup_add_simsmtp($setup): add SMTP simulation.
# SMTP transactions will be logged to the temporary directory and can be accessed
# using setup_get_tmpfile_name($setup, "smtp$n"). Linefeeds are normalized to "\n".
sub setup_add_simsmtp {
    my $setup = shift;

    # Verify
    _setup_verify($setup);
    if ($setup->{started}) { test_failure('Cannot add application server after starting setup') }

    # Set it up
    my $port = setup_allocate_port($setup);
    my $host = '127.0.0.1';
    my $svc = service_create('smtp', '/usr/bin/perl', 'simsmtp.pl');
    service_set_port($svc, $port);
    service_set_pingable($svc, 0);
    setup_add_service_config($setup,
                             "smtp.host", $host,
                             "smtp.port", $port,
                             "simsmtp.dir", $setup->{tmpdir});
    push @{$setup->{services}}, $svc;
    $svc;
}

# setup_add_apps($setup, @apps): add application services
# Like setup_add_app, for simple one-instance servers, e.g. 'talk', 'mailout'.
# Returns: list of handles
sub setup_add_apps {
    my $setup = shift;
    _setup_verify($setup);

    my @result;
    foreach my $name (@_) {
        push @result, setup_add_app($setup, $name, "c2$name");
    }
    wantarray ? @result : $result[0];
}

# setup_get_service($setup, $id): get service by name
sub setup_get_service {
    my $setup = shift;
    my $id = shift;
    _setup_verify($setup);
    if (!defined($id)) { test_failure('Missing $id'); }

    foreach (@{$setup->{services}}) {
        if (defined($_->{id}) && $id eq $_->{id}) {
            return $_;
        }
    }
    test_failure("Service '$id' not configured");
}

# setup_connect_app($setup, $id): connect to an app by name
sub setup_connect_app {
    service_connect(setup_get_service(@_));
}

# setup_add_home($setup): add a home directory
sub setup_add_home {
    my $setup = shift;
    _setup_verify($setup);
    my $home = setup_get_tmpfile_name($setup, 'home');
    mkdir $home, 0777 or die;
    $ENV{HOME} = $home;
    $home;
}

# setup_start($setup): start the setup (=create files and start all services).
sub setup_start {
    my $setup = shift;
    _setup_verify($setup);

    # Create c2config file
    my $c2c = "$setup->{tmpdir}/c2config.txt";
    open C2C, '>', $c2c or die "$c2c: $!";
    foreach (sort keys %{$setup->{service_config}}) {
        print C2C "$_ = $setup->{service_config}{$_}\n";
    }
    close C2C;
    $ENV{C2CONFIG} = $c2c;
    $setup->{started} = 1;

    # Start services
    foreach (@{$setup->{services}}) {
        service_start($_);
    }
}

# setup_start_wait($setup): like start, but wait for alls services.
sub setup_start_wait {
    my $setup = shift;
    _setup_verify($setup);

    setup_start($setup);
    foreach (@{$setup->{services}}) {
        service_connect_wait($_);
    }
}

# setup_stop($stop): stop the setup (=stop all services).
sub setup_stop {
    my $setup = shift;
    _setup_verify($setup);
    foreach (@{$setup->{services}}) {
        service_stop($_);
    }
    $setup->{started} = 0;
}

# Internal: load the system config file.
# Return: hash.
sub _setup_load_config {
    my $result = {};
    my $args = cmdl_parse();

    # Read config file
    foreach my $config_file (@{$args->{config_file}}) {
        -f $config_file or die "$config_file: not a file\n";
        open FILE, '<', $config_file or die "$config_file: $!\n";
        trace_creation("Reading $config_file...");
        while (<FILE>) {
            s/^\s+//; s/\s+$//;
            if (/^$/ || /^#/ || /^;/) {
                # ok
            } elsif (/^(\S+)\s*=\s*(.*)/) {
                $result->{lc($1)} = $2;
            } else {
                die "$config_file:$.: syntax error\n";
            }
        }
        close FILE;
    }

    # Merge args
    foreach (keys %{$args->{config}}) {
        $result->{$_} = $args->{config}{$_};
    }

    $result;
}

# Internal: process a basedir parameter for a file service and create a directory
sub _setup_wrap_dir {
    my ($setup, $basedir, $suffix) = @_;
    _setup_verify($setup);

    if ((defined($basedir) && $basedir eq 'auto')
        || (!defined($basedir) && _setup_file_is_classic($setup)))
    {
        my $root = setup_get_tmpfile_name($setup, $suffix);
        mkdir $root, 0777 or die "$root (mkdir): $!";
        $basedir = $root;
    }
    $basedir;
}

# Internal: check for classic c2file
sub _setup_file_is_classic {
    my $setup = shift;
    _setup_verify($setup);

    setup_get_system_config($setup, 'c2file.path') !~ /-server$/;
}

# Internal: verify $setup parameter.
sub _setup_verify {
    my $setup = shift;
    test_failure('Missing $setup') if !$setup || !ref($setup) || !$setup->{system_config} || !$setup->{service_config};
}

##
##  Service
##

# service_create($id, $command, opt @args): create a service.
# Return: service handle
sub service_create {
    # Validate
    my $id = shift;
    if (!defined($id))                         { test_failure('Missing $id') }
    if (!@_ || !defined($_[0]) || $_[0] eq '') { test_failure("Missing command") }
    if (!(-x $_[0] || -x "$_[0].exe"))         { test_failure("Program '$_[0]' not found") }

    my $name = $_[0];
    $name =~ s|^.*/||;

    # Do it
    trace_creation("Creating service: $id ($name)");
    return {
        id => $id,
        name => $name,
        command => [@_],
        started => 0,
        pid => 0,
        port => 0,
        pingable => 1,
        failed => 0
    };
}

# service_set_port($service, $port): set port number
sub service_set_port {
    my ($service, $port) = @_;
    _service_verify($service);
    $service->{port} = $port;
}

# service_get_port($service): get port number
sub service_get_port {
    my $service = shift;
    _service_verify($service);
    $service->{port};
}

# service_set_pingable($service, flag): set whether service can be pinged
sub service_set_pingable {
    my ($service, $flag) = @_;
    _service_verify($service);
    $service->{pingable} = $flag;
}

# service_start($service): start service. Can be called many times; does nothing if service already runs.
sub service_start {
    my $service = shift;
    _service_verify($service);
    if (!$service->{started}) {
        trace_detail("service_start: ", join(' ', @{$service->{command}}));
        my $pid = fork();
        die "fork: $!" if !defined $pid;
        if ($pid == 0) {
            if ($_log_level <= 1) {
                open STDOUT, '>', '/dev/null';
                open STDERR, '>', '/dev/null';
            }
            open STDIN, '<', '/dev/null';
            exec @{$service->{command}};
            die "exec $service->{command}[0]: $!\n";
        }
        trace_process("Started service: $service->{id} ($service->{name}, pid $pid)");
        $service->{started} = 1;
        $service->{pid} = $pid;
    }
}

# service_stop($service): stop service. Can be called many times; does nothing if service does not run.
sub service_stop {
    my $service = shift;
    _service_verify($service);
    if ($service->{started}) {
        my $pid = $service->{pid};
        trace_process("Stopping service: $service->{id} ($service->{name}, pid $pid)");
        kill 15, $pid;
        waitpid $pid, 0;
        $service->{started} = 0;
        $service->{pid} = 0;
        if ($? != 0 && $? != 15) {
            _print_backtrace("$service->{id} ($service->{name}) exited with code $?", 'Unexpected exit code', '31');
            $service->{failed} = 1;
            # do not die; this is part of post-die cleanup. Post-die cleanup will check for failed services.
        }
    }
}

# service_connect_raw($service): connect to service's port.
# Return: connection handle; undef on failure.
sub service_connect_raw {
    my $service = shift;
    _service_verify($service);

    if (!$service->{port}) { test_failure("No port number defined for $service->{id} ($service->{name})"); }
    if (!$service->{started}) { test_failure("Service $service->{id} ($service->{name}) not started before connect"); }

    my $fd = IO::Socket::INET->new(Proto=>"tcp", PeerAddr=>'127.0.0.1', PeerPort=>$service->{port});
    if (defined($fd)) {
        return { name => $service->{id} || $service->{name}, fd => $fd };
    } else {
        return undef;
    }
}

# service_connect_raw($service): connect to service's port, die on failure
# Return: connection handle
sub service_connect {
    my $service = shift;
    _service_verify($service);

    my $conn = service_connect_raw($service);
    if (!$conn) {
        die "$service->{id} ($service->{name}) on port $service->{port}: $!\n";
    }
    $conn;
}

# service_connect_wait($service): connect to service's port, wait until ready, die on failure.
# Return: connection handle
sub service_connect_wait {
    my $service = shift;
    _service_verify($service);

    foreach (1 .. 30) {
        my $conn = service_connect_raw($service);
        if ($conn && (!$service->{pingable} || eval {conn_call($conn, 'PING'); 1})) {
            return $conn;
        }

        sleep 0.1;
    }
    die "$service->{command}[0] on port $service->{port} not ready: $!\n";
}

# service_call_raw($service, $data): connect to service's port, write some data, read response.
sub service_call_raw {
    my $service = shift;
    my $text = shift;
    _service_verify($service);

    if (4 <= $_log_level) {
        # xref trace_detail
        trace_detail("service_call_raw ", $service->{id}, ": ", _censor_raw($text));
    }

    my $conn;
    foreach (1 .. 30) {
        $conn = service_connect_raw($service);
        last if $conn;
        sleep 0.1;
    }
    if (!$conn) {
        die "$service->{id} ($service->{name}) on port $service->{port}: $!\n";
    }

    $conn->{fd}->print($text);
    shutdown $conn->{fd}, 1;

    my $result = "";
    while (read $conn->{fd}, $result, 1024, length($result)) { }
    close $conn->{fd};
    $result;
}

# Internal: verify $service parameter.
sub _service_verify {
    my $service = shift;
    test_failure('Missing $service') if !$service || !ref($service) || !$service->{command};
}


##
##  Shell
##

# shell_new($setup, $name): create an instance for executing shell program $name.
sub shell_new {
    my $setup = shift;
    my $name = shift;
    _setup_verify($setup);

    return {
        name => $name,
        prog => setup_get_required_system_config($setup, "c2$name.path"),
        args => [],
        is_shell => 1,
        setup => $setup,
        opts => {}
    };
}

# shell_add_args($shell, @args): add command-line arguments.
sub shell_add_args {
    my $shell = shift;
    _shell_verify($shell);
    push @{$shell->{args}}, @_;
}

# shell_set_options($shell, opt=>val...): set sticky options
sub shell_set_options {
    my $shell = shift;
    _shell_verify($shell);
    _set_options($shell->{opts}, @_);
}

# shell_call($shell, $in, opt=>val): call shell, giving it a parameter, return output.
# Options:
#    expect_exit          expected exit code, default: 0
#    ignore_exit          nonzero to ignore the exit code
#    want_error           nonzero to capture stderr in addition to stdout
sub shell_call {
    my $shell = shift;
    my $in = shift;
    _shell_verify($shell);
    my %opts = %{$shell->{opts}};
    _set_options(\%opts, @_);

    trace_process("Calling shell: $shell->{prog}");
    trace(5, "Input: <<$in>>") if defined $in;

    # For simplicity, use temporary files
    my $in_name  = setup_get_tmpfile_name($shell->{setup}, 'shin'.++$_tmpdir_counter);
    my $out_name = setup_get_tmpfile_name($shell->{setup}, 'shout'.++$_tmpdir_counter);
    open FILE, ">", $in_name or die "$in_name: $!";
    print FILE $in if defined $in;
    close FILE;

    # Build the command
    my $cmd = join(' ', $shell->{prog}, @{$shell->{args}});
    $cmd .= " <$in_name";
    $cmd .= " >$out_name";
    $cmd .= " 2>&1" if $opts{want_error};

    # Execute
    my $exit_code = _execute($cmd);

    # Read output
    if (!-r $out_name) {
        assert_failure("Command '$cmd' did not produce output file");
    }
    my $result = file_content($out_name);
    trace(5, "Output: <<$result>>");

    # Evaluate result
    if (!$opts{ignore_exit}) {
        my $expect_exit = $opts{expect_exit} || 0;
        if ($exit_code != $expect_exit) {
            assert_failure("Command '$cmd' exited with $exit_code, expected $expect_exit");
        }
    }

    $result;
};

# Internal: verify $shell parameter.
sub _shell_verify {
    my $shell = shift;
    test_failure('Missing $shell') if !$shell || !ref($shell) || !$shell->{is_shell};
}


##
##  Operations on server connection
##

# conn_call($conn, @cmd): call command (RESP).
# Return: result
sub conn_call {
    my $conn = shift;
    _conn_verify($conn);

    if (4 <= $_log_level) {
        # xref trace_detail
        trace_detail("conn_call ", $conn->{name}, ": ", join(' ', map {_censor($_)} @_));
    }

    $conn->{fd}->print(_conn_resp_pack(@_));
    return _conn_resp_unpack($conn);
}

# conn_call_list($conn, @cmd): call command, expect list on return
sub conn_call_list {
    my $result = conn_call(@_);
    if (ref($result) ne 'ARRAY') {
        test_failure('Result is not a list');
    }
    @$result;
}

# conn_call_list_of_hash($conn, @cmd): call command, expect list of hashes on return
sub conn_call_list_of_hash {
    map {ref($_) ? {@$_} : $_} conn_call_list(@_);
}

# conn_interact($conn, $cmd, $multi): call command (line-based).
# If $cmd is non-empty, send that in one transaction (adds a \r\n).
# If $multi is given,
#   if line matches that regexp, reads a multiline reply and returns it.
#   otherwise, throws $multi.
# Otherwise, reads a single line and returns that.
sub conn_interact {
    my ($conn, $cmd, $multi) = @_;
    _conn_verify($conn);

    # Send command
    if (defined($cmd)) {
        trace_detail("conn_interact ", $conn->{name}, " send: ", _censor_raw($cmd));
        $conn->{fd}->print("$cmd\r\n");
    }

    # Read reply
    my $line = readline($conn->{fd});
    trace_detail("conn_interact ", $conn->{name}, " recv: ", _censor_raw($line));
    $line =~ s/\r//;
    if (defined($multi)) {
        if ($line !~ $multi) {
            assert_failure("$conn->{name}: expected multi-line reply, got '$line'");
        }
        $line = '';
        while (defined(my $next = readline($conn->{fd}))) {
            trace_detail("conn_interact ", $conn->{name}, " cont: ", _censor_raw($next));
            $next =~ s/\r//;
            last if $next eq ".\n";
            $next =~ s/^\.//;
            $line .= $next;
        }
    }
    return $line;
}

# Internal: pack array as RESP.
sub _conn_resp_pack {
    my $req = sprintf("*%d\r\n", scalar(@_));
    foreach (@_) {
        $req .= sprintf("\$%d\r\n%s\r\n", length($_), $_);
    }
    $req;
}

# Internal: _conn_resp_pack($conn): read RESP from connection.
sub _conn_resp_unpack {
    my $conn = shift;
    my $line = readline($conn->{fd});
    if (!defined($line)) {
        assert_failure("$conn->{name}: unexpected connection closure");
    }
    $line =~ s/\r?\n//;
    if ($line =~ /^\+(.*)/) {
        # Single-line reply, OK
        $1;
    } elsif ($line =~ /^-(.*)/) {
        # Error reply
        assert_failure($1);
    } elsif ($line =~ /^:(-?\d+)/) {
        # Integer reply
        0+$1;
    } elsif ($line =~ /^\$(\d+)/) {
        # Bulk reply
        my $text;
        read $conn->{fd}, $text, $1;
        readline($conn->{fd});             # skip a line
        $text;
    } elsif ($line =~ /^[\$\*]-1/) {
        # Negative multi/bulk reply
        undef;
    } elsif ($line =~ /^\*(\d+)/) {
        # Multi-bulk reply
        my $n = $1;
        my @result;
        foreach (1 .. $n) {
            push @result, _conn_resp_unpack($conn);
        }
        \@result;
    } else {
        # Huh?
        assert_failure("$conn->{name}: Invalid answer '$line'");
    }
}

# Internal: verify $conn parameter.
sub _conn_verify {
    my $conn = shift;
    test_failure('Missing $conn') if !$conn || !ref($conn) || !defined $conn->{fd};
}

##
##  Utilities
##

sub json_parse {
    my $str = shift;
    pos($str) = 0;
    _json_parse(\$str);
}

sub _json_parse {
    my $p = shift;
    $$p =~ m|\G\s*|sgc;
    if ($$p =~ m#\G"(([^\\"]+|\\.)*)"#gc) {
        # String: don't do anything fancy for now (charset translation, unicode escapes).
        my $s = $1;
        $s =~ s|\\(.)|_unquote($1)|eg;
        $s;
    } elsif ($$p =~ m|\G([-+]?\d+\.\d*)|gc) {
        $1;
    } elsif ($$p =~ m|\G([-+]?\.\d+)|gc) {
        $1;
    } elsif ($$p =~ m|\G([-+]?\d+)|gc) {
        $1;
    } elsif ($$p =~ m|\Gtrue\b|gc) {
        1
    } elsif ($$p =~ m|\Gfalse\b|gc) {
        0
    } elsif ($$p =~ m|\Gnull\b|gc) {
        undef
    } elsif ($$p =~ m|\G\{|gc) {
        my $result = {};
        while (1) {
            $$p =~ m|\G\s*|sgc;
            if ($$p =~ m|\G\}|gc) { last }
            elsif ($$p =~ m|\G,|gc) { }
            else {
                my $key = _json_parse($p);
                $$p =~ m|\G\s*|sgc;
                if ($$p !~ m|\G:|gc) { assert_failure("JSON syntax error: expecting ':', got '" . substr($$p, pos($$p), 20) . "'"); }
                my $val = _json_parse($p);
                $result->{$key} = $val;
            }
        }
        $result;
    } elsif ($$p =~ m|\G\[|gc) {
        my $result = [];
        while (1) {
            $$p =~ m|\G\s*|sgc;
            if ($$p =~ m|\G\]|gc) { last }
            elsif ($$p =~ m|\G,|gc) { }
            else { push @$result, _json_parse($p) }
        }
        $result;
    } else {
        assert_failure("JSON syntax error: expecting element, got '" . substr($$p, pos($$p), 20) . "'.");
    }
}

sub _unquote {
    my $x = shift;
    if ($x eq 'n') {
        return "\n";
    } elsif ($x eq 't') {
        return "\t";
    } elsif ($x eq 'r') {
        return "\r";
    } else {
        return $x;
    }
}

##
##  Asserts
##

# Some internal errors are reported as assertion failures, most notable the RESP error token.
# The intention is to get backtrace logs for those. When in an 'assert_throws', we expect a throw,
# and don't want the backtraces in output (but would like to catch the actual error).
# Therefore, we use this variable to modify the behaviour of 'assert_throws' to not print a
# backtrace, but just die().
my $_assert_inhibit = 0;

# assert(a): Assert true
sub assert {
    my $a = shift;
    if (!$a) {
        assert_failure("Condition not met");
    }
}

# assert_equals(a, b): Assert equality of strings.
sub assert_equals {
    my ($a, $b) = @_;
    if (!defined($a)) {
        assert_failure("Left value is not defined");
    }
    if (!defined($b)) {
        assert_failure("Right value is not defined");
    }
    if ($a ne $b) {
        assert_failure("'$a' not equal to '$b'");
    }
}

# assert_differs(a, b): Assert inequality of strings.
sub assert_differs {
    my ($a, $b) = @_;
    if ($a eq $b) {
        assert_failure("got '$a', expected difference");
    }
}

# assert_equals(a, b): Assert that a starts with b.
sub assert_starts_with {
    my ($a, $b) = @_;
    if (!defined($a)) {
        assert_failure("Left value is not defined");
    }
    if (!defined($b)) {
        assert_failure("Right value is not defined");
    }
    if (substr($a, 0, length($b)) ne $b) {
        assert_failure("'$a' does not start with '$b'");
    }
}

# assert_contains(a, b): Assert that a contains b.
sub assert_contains {
    my ($a, $b) = @_;
    if (!defined($a)) {
        assert_failure("Left value is not defined");
    }
    if (!defined($b)) {
        assert_failure("Right value is not defined");
    }
    if (index($a, $b) < 0) {
        assert_failure("'$a' does not contain '$b'");
    }
}

# assert_is_numeric(a): Assert that value is numeric (integer).
sub assert_is_numeric {
    my $a = shift;
    if ($a !~ /^-?\d+$/) {
        assert_failure("'$a' is not numeric");
    }
}

# assert_num_equals(a, b): Assert equality of numbers.
sub assert_num_equals {
    my ($a, $b) = @_;
    assert_is_numeric($a);
    assert_is_numeric($b);
    if ($a != $b) {
        assert_failure("'$a' not equal to '$b'");
    }
}

# assert_num_differs(a, b): Assert inequality of numbers.
sub assert_num_differs {
    my ($a, $b) = @_;
    assert_is_numeric($a);
    assert_is_numeric($b);
    if ($a == $b) {
        assert_failure("got '$a', expected difference");
    }
}

# assert_num_greater(a, b): Assert that a > b, numerically.
sub assert_num_greater {
    my ($a, $b) = @_;
    assert_is_numeric($a);
    assert_is_numeric($b);
    if ($a <= $b) {
        assert_failure("'$a' not greater than '$b'");
    }
}

# assert_set_equals(a, b): Assert that two sets, given as array references, are identical.
sub assert_set_equals {
    my ($a, $b) = @_;
    if (ref($a) ne 'ARRAY') { assert_failure("Left value is not an array reference"); }
    if (ref($b) ne 'ARRAY') { assert_failure("Right value is not an array reference"); }
    foreach my $ele (@$a) {
        if (!grep {$ele eq $_} @$b) { assert_failure("Left contains '$ele' which is missing in right"); }
    }
    foreach my $ele (@$b) {
        if (!grep {$ele eq $_} @$a) { assert_failure("Right contains '$ele' which is missing in left"); }
    }
}

# assert_list_equals(a, b): Assert that two lists, given as array references, are identical.
sub assert_list_equals {
    my ($a, $b) = @_;
    if (ref($a) ne 'ARRAY') { assert_failure("Left value is not an array reference"); }
    if (ref($b) ne 'ARRAY') { assert_failure("Right value is not an array reference"); }
    if (@$a != @$b)         { assert_failure(sprintf("Results have different length (%d != %d)", scalar(@$a), scalar(@$b))); }
    for (my $i = 0; $i < @$a; ++$i) {
        if (!defined $a->[$i]) {
            assert_failure("List difference at index $i: left is undefined");
        }
        if (!defined $b->[$i]) {
            assert_failure("List difference at index $i: right is undefined");
        }
        if ($a->[$i] ne $b->[$i]) {
            assert_failure("List difference at index $i: '$a->[$i]' != '$b->[$i]'")
        }
    }
}

# assert_execution_succeeds(@cmd): Assert that command executes successfully (exit 0).
sub assert_execution_succeeds {
    my $cmdl = join(' ', @_);
    my $err = _execute(@_);
    if ($err != 0) {
        assert_failure("'$cmdl' returns $err, expecting 0");
    }
}

# assert_binary_file_identical($a, $b, opt @ranges): Assert that files are identical.
# If @ranges is given as a list of [offset,length], only the given parts of the file are compared.
sub assert_binary_file_identical {
    my $a = shift;
    my $b = shift;
    if (!defined($a))                   { assert_failure("Missing first file name in assert_binary_file_identical"); }
    if (!defined($b))                   { assert_failure("Missing second file name in assert_binary_file_identical"); }
    open A, '<', $a                    or assert_failure("$a: $!");
    open B, '<', $b                    or assert_failure("$b: $!");
    my $aSize = (stat(A))[7];
    my $bSize = (stat(B))[7];
    if (!defined($aSize) || $aSize < 0) { assert_failure("$a: unable to determine size"); }
    if (!defined($bSize) || $bSize < 0) { assert_failure("$b: unable to determine size"); }
    if ($aSize != $bSize)               { assert_failure("Files '$a' and '$b' have different size ($aSize != $bSize)"); }

    my @todo = @_ ? @_ : ([0, $aSize]);
    foreach (@todo) {
        my $pos = $_->[0];
        my $length = $_->[1];
        if (!defined($pos))             { assert_failure("Missing position"); }
        if (!defined($length))          { assert_failure("Missing length"); }
        if ($pos > $aSize || $length > $aSize - $pos) { assert_failure("Range [$pos+length] exceeds file size $aSize"); }

        seek A, $pos, 0;
        seek B, $pos, 0;
        my $aText;
        my $bText;
        read A, $aText, $length;
        read B, $bText, $length;
        if ($aText ne $bText) {
            for (my $i = 0; $i < $length; ++$i) {
                my $aChar = ord(substr($aText, $i, 1));
                my $bChar = ord(substr($bText, $i, 1));
                if ($aChar != $bChar) {
                    assert_failure(sprintf("Files '%s' and '%s' differ; first difference at offset %d (0x%x) (0x%02x != 0x%02x)", $a, $b, $pos+$i, $pos+$i, $aChar, $bChar));
                }
            }
        }
    }
    close A;
    close B;
}

# assert_throws(sub{}, opt match): check code for match.
sub assert_throws {
    my $fn = shift;
    my $match = shift;

    my $ok = 1;
    my $save = $_assert_inhibit;
    eval {
        $_assert_inhibit = 1;
        $fn->();
        $ok = 0;
    };
    $_assert_inhibit = $save;
    if (!$ok) {
        assert_failure("Expected function to throw (die), but it did not");
    }
    if (defined($match)) {
        chomp($@);
        if (ref($match) eq 'Regexp') {
            if ($@ !~ $match) { assert_failure(sprintf("Error message '%s' does not match expected pattern '%s'", $@, $match)); }
        } elsif (ref($match)) {
            test_failure("Pattern must be string or regexp-reference");
        } else {
            if (index($@, $match) < 0) { assert_failure(sprintf("Error message '%s' does not contain expected substring '%s'", $@, $match)); }
        }
    }
}

sub assert_failure {
    my $msg = shift;
    if (!$_assert_inhibit) {
        _print_backtrace($msg, 'Assertion failure', '31');
        die "Assertion failure\n";
    } else {
        die "$msg\n";
    }
}

my $_backtrace_context;

sub set_context {
    $_backtrace_context = shift;
}

sub clear_context {
    undef $_backtrace_context;
}

sub _print_backtrace {
    my $msg = shift;
    my $kind = shift;
    my $color = shift;

    my $text = trace_color("$color;1", "$kind: $msg");
    my $error = trace_color(31, "error:");
    my $did = 0;
    my $i = 1;
    my $pos = "<unknown>";
    while (my ($pkg, $file, $line, $fn) = caller($i)) {
        if ($pkg ne 'c2systest' || $_debug) {
            $pos = "$file:$line";
            print STDERR "$pos: $error $text\n";
            $text = "  called from here";
            $did = 1;
        }
        last if ++$i >= 10;
    }

    if (!$did) {
        print STDERR "$pos: $error $text\n";
    }

    if (defined $_backtrace_context) {
        print STDERR "$pos: $error   with context $_backtrace_context\n";
    }
}

sub _execute {
    my $cmdl = join(' ', @_);
    trace_process("Executing: ", $cmdl);
    my $pid = fork();
    die "fork: $!" if !defined $pid;
    if ($pid == 0) {
        if ($_log_level <= 1) {
            open STDOUT, '>', '/dev/null';
            open STDERR, '>', '/dev/null';
        }
        open STDIN, '<', '/dev/null';
        exec @_;
        die "exec $cmdl: $!\n";
    }
    waitpid $pid, 0;
    return $?;
}

##
##  Summary
##

# summary_new(): create a summary. Use summary_add() to add to it, summary_print() to show it.
sub summary_new {
    return {
        _is_summary => 1,
        columns => [],
        rows    => [],
        name_to_col => {}
    };
}

# summary_add($sum, $key, $value, ...): add line to summary.
sub summary_add {
    my $sum = shift;
    _summary_verify($sum);

    my $this_row = [];
    while (@_) {
        my $key = shift;
        my $value = shift;
        my $this_col = $sum->{name_to_col}{$key};
        if (!defined $this_col) {
            $this_col = scalar(@{$sum->{columns}});
            push @{$sum->{columns}}, $key;
            $sum->{name_to_col}{$key} = $this_col;
        }
        while (@$this_row < $this_col) {
            push @$this_row, '';
        }
        $this_row->[$this_col] = $value;
    }
    push @{$sum->{rows}}, $this_row;
}

# summary_print($sum): print summary.
# Each summary_add() produces one table line.
# Keys are mapped to columns in the order they were seen.
# An empty summary produces no output at all.
sub summary_print {
    my $sum = shift;
    _summary_verify($sum);

    # Determine lengths
    my @lengths;
    foreach my $row ($sum->{columns}, @{$sum->{rows}}) {
        foreach my $i (0 .. $#$row) {
            my $len = length($row->[$i]);
            if (!defined $lengths[$i] || $lengths[$i] < $len) {
                $lengths[$i] = $len;
            }
        }
    }
    return if !@lengths;

    # Print headers
    my $head = '';
    my $div = '';
    trace(0, '');
    foreach my $i (0 .. $#lengths) {
        my $e = $sum->{columns}[$i];
        if (!defined($e)) { $e = '' }
        while (length($e) < $lengths[$i]) {
            $e .= ' ';
            if (length($e) < $lengths[$i]) {
                $e = ' '.$e;
            }
        }
        $head .= '  ' if $i;
        $head .= $e;
        $div .= '  ' if $i;
        $div .= '-' x length($e);
    }
    trace(0, $head);
    trace(0, $div);

    # Print content
    foreach my $row (@{$sum->{rows}}) {
        my $line = '';
        foreach my $i (0 .. $#lengths) {
            my $e = $row->[$i];
            if (!defined($e)) { $e = '' }
            $line .= '  ' if $i;
            if ($e =~ /^[-+]*[\d.]+%?$/) {
                $line .= sprintf("%$lengths[$i]s", $e);
            } else {
                $line .= sprintf("%-$lengths[$i]s", $e);
            }
        }
        $line =~ s/\s+$//;
        trace(0, $line);
    }
    trace(0, '');
}

sub _summary_verify {
    my $sum = shift;
    test_failure('Missing $sum') if !$sum || !ref($sum) || !$sum->{_is_summary};
}


##
##  Utilities
##
sub file_content {
    my $file = shift;
    if (!defined $file) { test_failure('Missing $file'); }
    open FILE, '<', $file or die "$file: $!\n";
    my $result = '';
    while (read FILE, $result, 4096, length($result)) { }
    close FILE;
    $result;
}

sub file_put {
    my $file = shift;
    my $content = shift;
    if (!defined $file) { test_failure('Missing $file'); }
    if (!defined $content) { test_failure('Missing $content'); }

    open FILE, '>', $file or die "$file: $!\n";
    binmode FILE;
    print FILE $content;
    close FILE;
}

sub file_wait {
    my $file = shift;
    if (!defined $file) { test_failure('Missing $file'); }
    my $n = 0;
    while (! -f $file) {
        if (++$n > 30) {
            assert_failure "$file did not appear";
        }
        sleep 0.1;
    }
}

##
##  Main test entry point
##

# test_if 'name', sub {...}, sub {...}: execute a conditional test case.
sub test_if {
    my $name = shift;
    my $cond = shift;
    my $fn = shift;

    cmdl_parse();
    ++$_test_current;
    if ($_test_only && $_test_only != $_test_current) {
        trace_test(trace_color('30;1', "SKIPPED"), " $name [#$_test_current]");
        1;
    } else {
        my $setup = setup_create($name);
        if (!$cond->($setup)) {
            trace_test(trace_color('30;1', "NOT-APPLICABLE"), " $name [#$_test_current]");
        } else {
            my $saved_log_level = $_log_level;

            trace_test("Running $name [#$_test_current]...");
            eval {
                $fn->($setup);
                $_log_level = $saved_log_level;
                setup_destroy($setup);
                if (grep {$_->{failed}} @{$setup->{services}}) {
                    die 'Failed services';
                }
                trace_test(trace_color(32, "SUCCESS"), " $name");
                1;
            } or do {
                $_log_level = $saved_log_level;
                setup_destroy($setup);
                trace_test(trace_color(31, "FAILURE"), " $name");
                die "$@";
            };
        }
        clear_context();
    }
}

# test 'name', sub {...}: execute a test case.
sub test {
    my $name = shift;
    my $fn = shift;
    test_if $name, sub { return 1 }, $fn;
}

# test_timing 'name', sub {...}: execute a timing/benchmark/performance test (time the runtime of the given sub).
# Repeatedly calls the given sub to determine its runtime.
# Usually called from the test sub, which provides a setup.
# This auto-calibrates the number of iterations for measurement to obtain a valid measurement.
# This means timing a "fast" sub doesn't necessarily run faster overall than timng a "slow" sub,
# if the fast one is measured with more iterations.
sub test_timing {
    my $name = shift;
    my $fn = shift;

    # Run once to preload caches
    $fn->();

    # Measurement loop
    my $count = 10;
    my $loops = 0;
    while (1) {
        # Run one measurement.
        my $t0 = time();
        foreach (1 .. $count) {
            $fn->();
        }
        my $t1 = time();

        # Attempt to reach a runtime between 0.5s and 2s.
        my $elapsed = $t1 - $t0;
        ++$loops;
        if ($loops > 10 || ($elapsed > 0.5 && $elapsed < 2)) {
            # Finish
            trace_test(trace_color('32;1', sprintf("%s: %d us", $name, (1000000*$elapsed / $count))), sprintf(" (%d in %.2fs = %d/s, loop %d)", $count, $elapsed, $count/$elapsed, $loops));
            last;
        } elsif ($elapsed < 0.001) {
            $count *= 300;    # <1ms -> <300ms
        } elsif ($elapsed < 0.01) {
            $count *= 30;     # <10ms -> <300ms
        } elsif ($elapsed < 0.1) {
            $count *= 3;      # <100ms -> <300ms
        } elsif ($elapsed < 1) {
            $count *= 2;      # <500ms -> <1s
        } elsif ($elapsed > 10) {
            $count /= 10;     # >10s -> >1s
        } else {
            $count /= 2;      # >2s -> >1s
        }
    }
}

sub _censor {
    my $x = shift;
    if ($x eq '') {
        "''";
    } elsif ($x =~ /[^\x21-\x7e]/) {
        sprintf("<%d>", length($x));
    } else {
        $x;
    }
}

sub _censor_raw {
    my $x = shift;
    $x =~ s/[\r\n].*//s;
    if ($x eq '') {
        "''";
    } elsif ($x =~ /[^\x20-\x7e]/) {
        sprintf("<%d>", length($x));
    } else {
        $x;
    }
}

sub _set_options {
    my $p = shift;
    die if ref($p) ne 'HASH';
    while (@_) {
        my $key = shift;
        if (!@_) { test_failure('Missing option value') }
        $p->{$key} = shift;
    }
}

1;

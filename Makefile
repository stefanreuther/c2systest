# Normal functionality test of almost-production configuration (mostly c2ng)
test:
	perl test.pl $(ARGS)

# Normal functionality test of classic system (will fail many tests)
test-classic:
	perl test.pl --config=system_classic.conf $(ARGS)

# Normal functionality test on isolated system
# This creates a new network namespace to ensure we don't accidentally interfere with "real" network.
#   unshare -r    "let me be root in my new namespace, so I can mess with my network stack"
#   unshare -n    "give me a new network stack"
#   ifconfig      loopback starts down/useless
test-isol:
	unshare -r -n perl test.pl -Dinitcommand='/sbin/ifconfig lo up' $(ARGS)

perf:
	perl test.pl --perf $(ARGS)

perf-classic:
	perl test.pl --perf --config=system_classic.conf $(ARGS)

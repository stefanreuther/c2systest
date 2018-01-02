test:
	perl test.pl

test-ng:
	perl test.pl --config=system_ng.conf

test-classic:
	perl test.pl --config=system_classic.conf

perf:
	perl test.pl --perf

perf-ng:
	perl test.pl --perf --config=system_ng.conf

perf-classic:
	perl test.pl --perf --config=system_classic.conf

.PHONY: test perf

#!/bin/sh
#
#  Run c2systest and create a coverage report
#
#  Compile c2ng with coverage enabled (Make.pl IN=... --enable-coverage).
#  Run this script, passing it the build directory as parameter.
#  Optionally, add more parameters for test.pl, e.g.
#        coverage.sh /path/to/c2ng router/
#  runs only the tests in router/.
#

set -e

# Check parameter
if test -z "$1"; then
  echo "Invocation: $0 <path-to-c2ng-coverage-build> [<options-for-test.pl>]" >&2
  exit 1
fi
dir=$1
shift

# Verify presence of files
# ('make resources' is easily forgotten)
for i in c2ng c2play-server share/specs/race.nm; do
  if ! test -e "$dir/$i"; then
    echo "Cannot find '$dir/$i'." >&2
    echo "Hint: do 'make all resources'" >&2
    exit 1
  fi
done

# Work directory
workdir=coverage_report/.tmp
rm -rf "$workdir"
mkdir -p "$workdir"

# Baseline
echo "Creating baseline..."
lcov -q -c -d "$dir" -i > "$workdir/init.info"

# Locate source directory
srcdir=$(perl -ne 'if (m|^SF:(.*)/game/element.cpp|) { print "$1"; exit }' < "$workdir/init.info")
if test -z "$srcdir"; then
  echo "Unable to locate source directory." >&2
  exit 1
fi

# Run tests
echo "Clearing results..."
lcov -q -z -d "$dir"
echo "Running tests..."
perl test.pl -Dc2ng="$dir" "$@" || true
echo "Capturing results..."
lcov -q -c -d "$dir" > "$workdir/test.info"

# Combine
echo "Merging results..."
lcov -q -a "$workdir/init.info" -a "$workdir/test.info" > "$workdir/combined.info"
echo "Filtering results..."
lcov -q -e "$workdir/combined.info" "$srcdir/*" > "$workdir/result.info"

# Generate output
echo "Generating output..."
genhtml -q -t "c2systest" -o coverage_report "$workdir/result.info" --ignore-errors source

#!/usr/bin/env perl
# Memory Hog - Chapter 10 Exercise
#
# Allocates memory in 1 MB chunks until killed by the OOM killer
# or the user presses Ctrl+C.
#
# Usage:
#     perl memory-hog.pl [MB]
#     perl memory-hog.pl 500    # allocate 500 MB then wait
#     perl memory-hog.pl 0      # allocate until OOM kills us
#
# WARNING: Run inside a cgroup with MemoryMax set, or in a VM/container.
#          Do NOT run on a production system.
#
# Safe testing with systemd-run:
#     sudo systemd-run --scope -p MemoryMax=256M perl memory-hog.pl 0

use strict;
use warnings;

$SIG{INT} = sub { print "\nInterrupted. Releasing memory.\n"; exit 0; };

my $target_mb = $ARGV[0] // 500;
my $unlimited = ($target_mb == 0);
my @blocks;
my $allocated = 0;

if ($unlimited) {
    print "Allocating memory until OOM killer intervenes...\n";
    print "Press Ctrl+C to stop early.\n\n";
} else {
    print "Allocating $target_mb MB of memory...\n";
}

while ($unlimited || $allocated < $target_mb) {
    # Allocate 1 MB of actual data
    push @blocks, "x" x (1024 * 1024);
    $allocated++;

    if ($allocated % 50 == 0) {
        print "  $allocated MB allocated (PID $$)\n";
    }
}

print "\nDone: $allocated MB allocated. PID $$\n";
print "Memory is held. Press Enter to release, or wait for OOM killer.\n";
<STDIN>;
print "Releasing memory.\n";

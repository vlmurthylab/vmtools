#!/usr/bin/env perl
# Lab core: identical in every lab repository; change it in
# vlmurthylab/project-template.
#
# Tests for tools/phi_guard.pl, run by the GitHub check and by hand:
#   perl tools/test_phi_guard.pl
# Each case makes a throwaway git repository holding the check and one or two
# made-up files, runs the check on it, and compares the result. Nothing here
# is real data. Digit runs are built by joining short pieces, so this file
# does not itself look like PHI to the check.

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

my $guard = abs_path(File::Spec->catfile(dirname(abs_path($0)), 'phi_guard.pl'));

# Made-up values, built from pieces.
my $day   = '2026' . '1102';                 # a date as 8 digits
my $hex8  = '1a2b' . '3c4d';
my $sha   = join '', ('0123456789abcdef') x 4;   # 64 hex
my $mrn   = '123' . '4567';                  # 7 digits

my $extract = "[nclr-extract:$day:$hex8]";
my $time    = "[t:$day-1430]";
my $sum     = "[sha256:$sha]";

my @cases = (
  # name, files { path => content }, expect pass (1) or fail (0), [text the message must hold]
  ['tokens in a note pass',          { 'docs/run.md' => "Extract $extract, run $time, table2.csv $sum\n" }, 1],
  ['tokens in an output pass',       { 'results/report.txt' => "$extract\n$time\n$sum\n" }, 1],
  ['tokens in code pass',            { 'code/a.R' => "cite <- \"$extract\"\n" }, 1],
  # MRN-like numbers: an underscore or a file extension doesn't hide them.
  ['MRN after an underscore fails',  { 'docs/run.md' => "export_$mrn.csv\n" }, 0, 'MRN-like'],
  ['MRN before an extension fails',  { 'docs/run.md' => "see $mrn.pdf\n" }, 0, 'MRN-like'],
  ['MRN between underscores fails',  { 'code/a.R' => "f <- \"labs_${mrn}_v2.csv\"\n" }, 0, 'MRN-like'],
  ['MRN in a file name next to a token fails',
                                     { 'docs/run.md' => "export_$mrn.csv $sum\n" }, 0, 'MRN-like'],
  ['decimals, hashes and thousands commas pass',
                                     { 'docs/run.md' => "p = 0.$mrn; x = $mrn.25; y = $mrn.05; id abc${mrn}def; n = 1,234,567\n" }, 1],
  ['MRN in a CSV row fails',         { 'results/tables/t.csv' => "id_x,age\n$mrn,45\n" }, 0, 'MRN-like'],
  ['MRN in JSON fails',              { 'results/out.json' => "{\"rec\":$mrn,\"age\":45}\n" }, 0, 'MRN-like'],
  ['MRN read as a float fails',      { 'results/out.txt' => "rec $mrn.0\n" }, 0, 'MRN-like'],
  ['DOIs, leading-dot decimals and SVG coordinates pass',
                                     { 'docs/refs.md' => "doi 10.1371/journal.pone.0$mrn and pnas.1$mrn; p = .$mrn\n",
                                       'results/figures/f.svg' => "<path d=\"M -.00$mrn L 1 2\"/>\n" }, 1],
  ['MRN right after the letters MRN fails',
                                     { 'docs/run.md' => "MRN${mrn}_labs.pdf\n" }, 0, 'MRN-like'],
  ['MRN after MRN and a dot fails',  { 'docs/run.md' => "col MRN.$mrn and mrn.$mrn.pdf\n" }, 0, 'MRN-like'],
  ['MRN in groups after MRN fails',  { 'docs/run.md' => "MRN 123-" . "456-789\n" }, 0, 'MRN-like'],
  ['MRN in groups after MRN- fails', { 'docs/run.md' => "MRN-123-" . "456-789 and MRN_123-" . "456-789\n" }, 0, 'MRN-like'],
  ['counts after a label with mrn in it pass',
                                     { 'results/summary.md' => "n_mrn 1520 1498\nunique_mrn\t2031\t1987\n",
                                       'code/a.R' => "# MRN 2024-" . "11-05 cutoff\n" }, 1],
  ['MRN as an R column name fails',  { 'results/out.txt' => "  X$mrn  X2\n" }, 0, 'MRN-like'],
  ['hex literals and sizes pass',    { 'code/a.py' => "m = 0x$mrn; size = '1920x1080'\n" }, 1],
  ['MRN after a word ending in MRN fails',
                                     { 'docs/run.md' => "patientMRN$mrn\n" }, 0, 'MRN-like'],
  ['lower-case mrn with a separator fails',
                                     { 'code/a.R' => "f <- \"mrn_$mrn\"\n" }, 0, 'MRN-like'],
  ['MRN at the start and end of a line fails',
                                     { 'docs/run.md' => "$mrn\r\n" }, 0, 'MRN-like'],
  ['bare 8-digit date fails',        { 'results/report.txt' => "extract $day\n" }, 0, 'MRN-like'],
  ['MRN after a token fails',        { 'docs/run.md' => "$extract $mrn\n" }, 0, 'MRN-like'],
  ['ISO date beside a token fails',  { 'results/report.txt' => "$time " . join("-", "2026", "11", "02") . "\n" }, 0, 'full date'],
  ['impossible month is no token',   { 'docs/run.md' => "[t:" . "2026" . "1302-1430]\n" }, 0, 'MRN-like'],
  ['short extract hex is no token',  { 'docs/run.md' => "[nclr-extract:$day:1a2b3c]\n" }, 0, 'MRN-like'],
  ['upper-case hex is no token',     { 'docs/run.md' => "[nclr-extract:$day:1A2B3C4D]\n" }, 0, 'MRN-like'],
  ['unbracketed token fails',        { 'docs/run.md' => "nclr-extract:$day:$hex8\n" }, 0, 'MRN-like'],
  ['good extract-version.txt passes',
                                     { 'extract-version.txt' => "$extract main cohort\n[nclr-extract:$day:deadbeef] sensitivity analysis\r\n" }, 1],
  ['extract-version.txt with a bare date fails',
                                     { 'extract-version.txt' => "$day main cohort\n" }, 0, 'extract-version.txt must be'],
  ['extract-version.txt with an extra line fails',
                                     { 'extract-version.txt' => "$extract main cohort\nsee notes\n" }, 0, ':2: each line'],
  ['extract-version.txt with a blank line fails',
                                     { 'extract-version.txt' => "$extract main cohort\n\n$extract other\n" }, 0, ':2: each line'],
  ['extract-version.txt without a label fails',
                                     { 'paper/extract-version.txt' => "$extract\n" }, 0, 'each line'],
  ['empty extract-version.txt fails',
                                     { 'extract-version.txt' => "" }, 0, 'is empty'],
  ['extract-version.txt label is still checked',
                                     { 'extract-version.txt' => "$extract cohort $mrn\n" }, 0, 'MRN-like'],
  ['ALLOW_FILES does not exempt extract-version.txt',
                                     { 'extract-version.txt' => "notes\n", 'phi-guard.conf' => "ALLOW_FILES=extract-version.txt\n" }, 0, 'each line'],
);

my ($pass, $fail) = (0, 0);
for my $c (@cases) {
  my ($name, $files, $want, $msg) = @$c;
  my $dir = tempdir(CLEANUP => 1);
  run($dir, 'git', 'init', '-q');
  mkdir "$dir/tools";
  write_file("$dir/tools/phi_guard.pl", slurp($guard));
  write_file("$dir/$_", $files->{$_}) for keys %$files;
  run($dir, 'git', 'add', '-A');
  my $out = `cd "$dir" && perl tools/phi_guard.pl --all 2>&1`;
  my $ok = $? == 0 ? 1 : 0;
  my $good = $ok == $want && (!defined $msg || index($out, $msg) >= 0);
  if ($good) { $pass++; print "ok   $name\n" }
  else { $fail++; print "FAIL $name (exit " . ($ok ? 0 : 1) . ")\n" . ($out =~ s/^/     /mgr) }
}
print "\n$pass passed, $fail failed\n";
exit($fail ? 1 : 0);

sub run { my ($dir, @cmd) = @_; system('sh', '-c', 'cd "$0" && "$@"', $dir, @cmd) == 0 or die "failed: @cmd\n" }
sub slurp { my ($f) = @_; open my $fh, '<', $f or die "$f: $!\n"; local $/; <$fh> }
sub write_file {
  my ($f, $text) = @_;
  my $d = dirname($f); system('mkdir', '-p', $d) == 0 or die;
  open my $fh, '>', $f or die "$f: $!\n"; binmode $fh; print $fh $text; close $fh;
}

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

my $bytes = '2016' . '6090';                 # a package size in bytes
my $ms    = '1726' . '0000' . '00000';       # a build time in milliseconds

# Made-up lock files, shaped like the ones uv and pixi write.
my $uv_entry = "{ url = \"https://files.example.org/demo-1.0.tar.gz\", hash = \"sha256:$sha\", size = $bytes, upload-time = \"2024-11-02T17:48:55.832Z\" }";
my $uv_lock  = "version = 1\nrevision = 3\nrequires-python = \">=3.11\"\n\n[[package]]\nname = \"demo\"\n"
             . "version = \"1.0\"\nsource = { registry = \"https://pypi.org/simple\" }\nsdist = $uv_entry\n"
             . "wheels = [\n    $uv_entry,\n]\n";
my $pixi_lock = "version: 6\nenvironments:\n  default:\n    channels:\n    - url: https://conda.anaconda.org/conda-forge/\n"
              . "packages:\n- conda: https://conda.anaconda.org/conda-forge/noarch/demo-1.0-pyh0_0.conda\n"
              . "  sha256: $sha\n  md5: " . substr($sha, 0, 32) . "\n  license: MIT\n  size: $bytes\n  timestamp: $ms\n";

# 250 records (over the default MAX_TABLE_ROWS of 200), as JSON and as YAML.
my $json_recs = join(",\n", map { "    {\n      \"name\": \"p$_\",\n      \"version\": \"1.0\"\n    }" } 1 .. 250);
my $yaml_recs = join('', map { "- name: p$_\n  version: 1.0\n" } 1 .. 250);
my $npm_start = "{\n  \"name\": \"demo\",\n  \"version\": \"1.0.0\",\n  \"lockfileVersion\": 3,\n";
# The same records as packages, each with a checksum, as lock files write them.
my $b64 = join '', ('AbCdEfGh') x 11;        # base64, 88 characters
my $json_pkgs = join(",\n", map { "    {\n      \"name\": \"p$_\",\n      \"version\": \"1.0\",\n      \"integrity\": \"sha512-$b64\"\n    }" } 1 .. 250);
my $yaml_pkgs = join('', map { "- name: p$_\n  version: 1.0\n  hash:\n    md5: " . substr($sha, 0, 32) . "\n" } 1 .. 250);
# Poetry before 1.2: no header, and a [metadata.files] list of every download.
my $poetry_old = "[[package]]\nname = \"demo\"\nversion = \"1.0\"\n\n[metadata.files]\n"
               . join('', map { my $p = $_; "p$p = [\n" . join('', map { "    {file = \"p$p-1.0-py3-$_.whl\", hash = \"sha256:$sha\"},\n" } 1 .. 5) . "]\n" } 1 .. 60);

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
  # Lock files: package sizes and build times pass; nothing else is exempt.
  ['uv.lock package sizes pass',     { 'uv.lock' => $uv_lock, 'sub/uv.lock' => $uv_lock }, 1],
  ['uv.lock MRN elsewhere fails',    { 'uv.lock' => $uv_lock =~ s/name = "demo"/name = "demo-$mrn"/r }, 0, 'uv.lock:6: looks like an MRN'],
  ['uv.lock MRN after a size fails', { 'uv.lock' => $uv_lock =~ s/upload-time = "[^"]*"/upload-time = "$mrn"/r }, 0, 'MRN-like'],
  ['uv.lock size outside a package entry fails',
                                     { 'uv.lock' => "$uv_lock\n[extra]\nsize = $mrn\n" }, 0, 'MRN-like'],
  ['a file only named uv.lock fails', { 'uv.lock' => "id,age\n$mrn,45\n" }, 0, 'MRN-like'],
  ['pixi.lock sizes and build times pass',
                                     { 'pixi.lock' => $pixi_lock }, 1],
  ['pixi.lock MRN elsewhere fails',  { 'pixi.lock' => $pixi_lock =~ s/license: MIT/license: $mrn/r }, 0, 'MRN-like'],
  ['pixi.lock size with more on the line fails',
                                     { 'pixi.lock' => $pixi_lock =~ s/size: $bytes/size: $bytes $mrn/r }, 0, 'MRN-like'],
  ['a file only named pixi.lock fails', { 'pixi.lock' => "records:\n  size: $mrn\n" }, 0, 'MRN-like'],
  # The exact forms each tool writes, and nothing looser.
  ['uv.lock from uv before 0.7 passes',
                                     { 'uv.lock' => $uv_lock =~ s/, upload-time = "[^"]*" \}/ }/gr }, 1],
  ['uv.lock with Windows line endings passes',
                                     { 'uv.lock' => $uv_lock =~ s/\n/\r\n/gr, 'pixi.lock' => $pixi_lock =~ s/\n/\r\n/gr }, 1],
  ['uv.lock MRN in a package URL fails',
                                     { 'uv.lock' => $uv_lock =~ s{demo-1\.0\.tar\.gz}{demo-$mrn.tar.gz}r }, 0, 'MRN-like'],
  ['uv.lock entry not for a package archive fails',
                                     { 'uv.lock' => $uv_lock =~ s{demo-1\.0\.tar\.gz}{rows}r }, 0, 'MRN-like'],
  ['uv.lock size with a decimal fails', { 'uv.lock' => $uv_lock =~ s/size = $bytes/size = $mrn.0/r }, 0, 'MRN-like'],
  ['a lock file name in other case gets every check',
                                     { 'UV.lock' => $uv_lock, 'Pixi.lock' => $pixi_lock }, 0, 'MRN-like'],
  ['a lock file that starts another way gets every check',
                                     { 'uv.lock' => "\n$uv_lock" }, 0, 'MRN-like'],
  ['pixi.lock size indented further fails',
                                     { 'pixi.lock' => $pixi_lock =~ s/  size: /    size: /r }, 0, 'MRN-like'],
  ['pixi.lock size indented by a tab fails',
                                     { 'pixi.lock' => $pixi_lock =~ s/  size: /\tsize: /r }, 0, 'MRN-like'],
  ['pixi.lock size outside a package entry fails',
                                     { 'pixi.lock' => "version: 6\nnotes: |\n  size: $mrn\n", 'sub/pixi.lock' => "version: 6\n  size: $mrn\n" }, 0, 'MRN-like'],
  ['pixi.lock size after a package entry ends fails',
                                     { 'pixi.lock' => "$pixi_lock" . "records:\n  size: $mrn\n" }, 0, 'pixi.lock:14: looks like an MRN'],
  ['pixi.lock timestamp of the wrong length fails',
                                     { 'pixi.lock' => $pixi_lock =~ s/timestamp: $ms/timestamp: $mrn/r }, 0, 'MRN-like'],
  # Lock files skip the record counts only when their records carry checksums.
  ['lock files with many checksummed packages pass',
                                     { 'package-lock.json' => "$npm_start  \"packages\": [\n$json_pkgs\n  ]\n}\n",
                                       'sub/conda-lock.yml' => "# This lock file was generated by conda-lock.\npackage:\n$yaml_pkgs",
                                       'poetry.lock' => $poetry_old }, 1],
  ['JSON records saved as package-lock.json fail',
                                     { 'package-lock.json' => "[\n$json_recs\n]\n" }, 0, 'looks like row-level data'],
  ['JSON records with a lock file\'s first lines fail',
                                     { 'package-lock.json' => "$npm_start  \"packages\": [\n$json_recs\n  ]\n}\n" }, 0, 'looks like row-level data'],
  ['YAML records saved as conda-lock.yml fail',
                                     { 'sub/conda-lock.yml' => "package:\n$yaml_recs" }, 0, 'looks like row-level data'],
  ['records with too few checksums fail',
                                     { 'renv.lock' => "{\n  \"Hash\": \"$sha\",\n  \"x\": [\n$json_recs\n]}\n" }, 0, 'looks like row-level data'],
  ['checksums all on one line do not count',
                                     { 'renv.lock' => "{\n  \"note\": \"" . join(' ', (substr($sha, 0, 32)) x 150) . "\",\n  \"x\": [\n$json_recs\n]}\n" }, 0, 'looks like row-level data'],
  ['HTML table rows under a lock file name fail',
                                     { 'uv.lock' => "version = 1\n# $sha\n<table>\n" . join('', map { "<tr><td>p$_</td></tr>\n<!-- $sha -->\n" } 1 .. 250) . "</table>\n" }, 0, 'HTML table rows'],
  ['pixi environment references are not records',
                                     { 'pixi.lock' => "version: 6\nenvironments:\n" . join('', map { my $e = $_; "  e$e:\n    packages:\n      linux-64:\n" . join('', map { "      - conda: https://conda.example.org/p$_-1.0.conda\n" } 1 .. 60) } 1 .. 5) . "packages:\n- conda: https://conda.example.org/p1-1.0.conda\n  sha256: $sha\n" }, 1],
  ['a lock file name in other case gets the record counts',
                                     { 'PACKAGE-LOCK.JSON' => "$npm_start  \"packages\": [\n$json_pkgs\n  ]\n}\n" }, 0, 'looks like row-level data'],
  ['sizes in other files fail',      { 'docs/notes.md' => "size = $mrn\n", 'results/out.yml' => "  timestamp: $mrn\n" }, 0, 'MRN-like'],
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

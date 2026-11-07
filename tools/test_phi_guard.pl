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
my $yaml_pkgs = join('', map { "- name: p$_\n  version: 1.0\n  hash:\n    md5: " . substr($sha, 0, 32) . "\n" } 1 .. 250);
# A uv.lock as uv writes it: per package, two wheels, each with its sha256
# (one "}, {" between them), and four dependencies with no hash (three more).
# That is 2 package checksums for 4 records: exactly the 1-in-2 the rule needs.
my $uv_pkg = sub { my ($p, $wheels, $deps) = @_;
  "\n[[package]]\nname = \"p$p\"\nversion = \"1.0\"\nsource = { registry = \"https://pypi.org/simple\" }\n"
  . "dependencies = [\n" . join(",\n", map { "    { name = \"d$_\" }" } 1 .. $deps) . ",\n]\n"
  . "wheels = [\n" . join(",\n", map { "    { url = \"https://files.example.org/p$p-1.0-$_.whl\", hash = \"sha256:$sha\", size = $bytes }" } 1 .. $wheels) . ",\n]\n" };
my $uv_head = "version = 1\nrequires-python = \">=3.11\"\n";
my $uv_big  = $uv_head . join('', map { $uv_pkg->($_, 2, 4) } 1 .. 120);
my $uv_thin = $uv_head . join('', map { $uv_pkg->($_, 1, 4) } 1 .. 120);   # 1 checksum for 3 records
# Hashed IDs in the self-describing "sha256:<hex>" form, and as provenance tokens.
my $prefixed_json = join(",\n", map { "    {\n      \"pid_hash\": \"sha256:$sha\",\n      \"age\": 40\n    }" } 1 .. 250);
my $prefixed_yaml = join('', map { "- pid_hash: sha256:$sha\n  age: 40\n" } 1 .. 250);
my $prefixed_toml = join(",\n", map { "{\n  pid_hash = \"sha256:$sha\",\n  age = 40\n}" } 1 .. 250);
my $oneline_toml = join(",\n", map { "{ mrn.hash = \"sha256:$sha\",\n  age = 40\n}" } 1 .. 250);
my $hash_json     = join(",\n", map { "    { \"hash\": \"sha256:$sha\",\n      \"age\": 40\n    }" } 1 .. 250);
my $bare_uv       = join(",\n", map { "{ hash = \"$sha\",\n  age = 40\n}" } 1 .. 250);
my $dash_yaml     = join('', map { "- sha256: $sha\n  age: 40\n" } 1 .. 250);
my $json_sha_key  = join(",\n", map { "    {\n      \"sha256\": \"$sha\",\n      \"age\": 40\n    }" } 1 .. 250);
my $trailing_yaml = join('', map { "- name: p$_\n  sha256: $sha extra\n" } 1 .. 250);
# pixi packages as pixi writes them: the sha256 line on its own.
my $pixi_pkgs     = join('', map { "- name: p$_\n  version: 1.0\n  sha256: $sha\n" } 1 .. 250);
# One record past 1 in 2: $uv_big plus one more record, no more checksums.
my $uv_short = "$uv_big\nextra = [\n    { name = \"x\" },\n    { name = \"y\" },\n]\n";
my $token_json    = join(",\n", map { "    {\n      \"file\": \"[sha256:$sha]\",\n      \"age\": 40\n    }" } 1 .. 250);
# A renv.lock as renv 1.x writes it: a package's DESCRIPTION fields include
# an email, a release date and a long number; the header a dated snapshot URL.
my $email = 'ann' . '@' . 'example.org';
my $iso   = '2024' . '-01-15';
my $renv_pkg = "    \"demo\": {\n      \"Package\": \"demo\",\n      \"Version\": \"1.0\",\n"
             . "      \"Authors\@R\": \"person(\\\"Ann\\\", \\\"Lee\\\", email = \\\"$email\\\")\",\n"
             . "      \"Maintainer\": \"Ann Lee <$email>\",\n      \"Date\": \"$iso\",\n"
             . "      \"Description\": \"See doi:10.1000/$mrn for details.\",\n"
             . "      \"Requirements\": [\n        \"R\"\n      ],\n      \"Hash\": \"" . substr($sha, 0, 32) . "\"\n    }\n";
my $renv_head = "{\n  \"R\": {\n    \"Version\": \"4.4.2\",\n    \"Repositories\": [\n      {\n        \"Name\": \"RSPM\",\n"
              . "        \"URL\": \"https://packagemanager.posit.co/cran/$iso\"\n      }\n    ]\n  },\n";
my $renv_ok = "$renv_head  \"Packages\": {\n$renv_pkg  }\n}\n";
# Made-up de-identified rows, each with a hashed ID (vlmurthylab/project-template#14).
my $hashed_json = join(",\n", map { "    {\n      \"pid_hash\": \"$sha\",\n      \"age\": 40,\n      \"ldl\": 120\n    }" } 1 .. 250);
my $hashed_bare = join(",\n", map { "    {\n      \"name\": \"p$_\",\n      \"type\": \"outpatient\",\n      \"size\": 3,\n      \"hash\": \"$sha\"\n    }" } 1 .. 250);
my $hashed_dots = join(",\n", map { "    {\n      \"mrn.sha256\": \"$sha\",\n      \"age\": 40\n    }" } 1 .. 250);
my $hashed_yaml = join('', map { "- name: p$_\n  age: 40\n  mrn_sha256: $sha\n" } 1 .. 250);
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
                                     { 'uv.lock' => $uv_big, 'sub/pixi.lock' => "version: 6\npackages:\n$yaml_pkgs" }, 1],
  ['JSON records saved as uv.lock fail',
                                     { 'uv.lock' => "[\n$json_recs\n]\n" }, 0, 'looks like row-level data'],
  ['JSON records with a lock file\'s first lines fail',
                                     { 'uv.lock' => "version = 1\n[\n$json_recs\n]\n" }, 0, 'looks like row-level data'],
  ['YAML records saved as pixi.lock fail',
                                     { 'sub/pixi.lock' => "version: 6\npackages:\n$yaml_recs" }, 0, 'looks like row-level data'],
  # Only uv.lock and pixi.lock get the allowance: other names get every check,
  # even with uv-form checksums.
  ['an npm lock file gets every check',
                                     { 'package-lock.json' => $uv_big }, 0, 'looks like row-level data'],
  ['a composer lock file gets every check',
                                     { 'composer.lock' => $uv_big }, 0, 'looks like row-level data'],
  ['a conda-lock file gets every check',
                                     { 'conda-lock.yml' => "package:\n$yaml_pkgs" }, 0, 'looks like row-level data'],
  ['records with a hashed ID under a lock file name fail',
                                     { 'uv.lock' => "version = 1\n[\n$hashed_json\n]\n" }, 0, 'looks like row-level data'],
  ['one package checksum per three records fails',
                                     { 'uv.lock' => $uv_thin }, 0, 'looks like row-level data'],
  ['hashed IDs written sha256:<hex> do not count',
                                     { 'uv.lock' => "version = 1\n[\n$prefixed_json\n]\n" }, 0, 'looks like row-level data'],
  ['hashed IDs written sha256:<hex> in YAML do not count',
                                     { 'pixi.lock' => "version: 6\npackages:\n$prefixed_yaml" }, 0, 'looks like row-level data'],
  ['a hash = "sha256:<hex>" key ending in hash does not count',
                                     { 'uv.lock' => "version = 1\nrows = [\n$prefixed_toml\n]\n" }, 0, 'looks like row-level data'],
  ['pixi sha256 lines count as package checksums',
                                     { 'pixi.lock' => "version: 6\npackages:\n$pixi_pkgs" }, 1],
  ['one record past 1 in 2 fails',
                                     { 'uv.lock' => $uv_short }, 0, 'looks like row-level data'],
  ['a dotted key ending in hash does not count',
                                     { 'uv.lock' => "version = 1\nrows = [\n$oneline_toml\n]\n" }, 0, 'looks like row-level data'],
  ['a JSON "hash" key does not count',
                                     { 'uv.lock' => "version = 1\n[\n$hash_json\n]\n" }, 0, 'looks like row-level data'],
  ['uv form without sha256: does not count',
                                     { 'uv.lock' => "version = 1\nrows = [\n$bare_uv\n]\n" }, 0, 'looks like row-level data'],
  ['a sha256 key starting a YAML record does not count',
                                     { 'pixi.lock' => "version: 6\npackages:\n$dash_yaml" }, 0, 'looks like row-level data'],
  ['a quoted JSON sha256 key does not count',
                                     { 'pixi.lock' => "version: 6\n[\n$json_sha_key\n]\n" }, 0, 'looks like row-level data'],
  ['a sha256 line with more on it does not count',
                                     { 'pixi.lock' => "version: 6\npackages:\n$trailing_yaml" }, 0, 'looks like row-level data'],
  ['pixi references with Windows line endings are not records',
                                     { 'pixi.lock' => ("version: 6\nenvironments:\n  e1:\n    packages:\n      linux-64:\n" . join('', map { "      - conda: https://conda.example.org/p$_-1.0.conda\n" } 1 .. 250)) =~ s/\n/\r\n/gr }, 1],
  ['uv git dependencies count by their commit',
                                     { 'uv.lock' => $uv_head . join('', map { "\n[[package]]\nname = \"g$_\"\nversion = \"1.0\"\nsource = { git = \"https://github.com/example/g$_?rev=main#" . substr($sha, 0, 40) . "\" }\ndependencies = [\n    { name = \"a\" },\n    { name = \"b\" },\n    { name = \"c\" },\n]\n" } 1 .. 120) }, 1],
  ['an MRN-like hit in a uv.lock gets the lock-file note',
                                     { 'uv.lock' => "$uv_head\n[[package]]\nname = \"tz\"\nversion = \"$day\"\n" }, 0, 'never add phi-ok to it'],
  ['a uv.lock that starts another way gets the record counts',
                                     { 'uv.lock' => "# note\n$uv_big" }, 0, 'looks like row-level data'],
  ['a pixi.lock that starts another way gets the record counts',
                                     { 'pixi.lock' => "packages:\n$pixi_pkgs" }, 0, 'looks like row-level data'],
  ['uv git commits must be the full 40 hex',
                                     { 'uv.lock' => $uv_head . join('', map { "\n[[package]]\nname = \"g$_\"\nversion = \"1.0\"\nsource = { git = \"https://github.com/example/g$_?rev=main#" . substr($sha, 0, 7) . "\" }\ndependencies = [\n    { name = \"a\" },\n    { name = \"b\" },\n    { name = \"c\" },\n]\n" } 1 .. 120) }, 0, 'looks like row-level data'],
  ['pixi md5 lines must be exactly 32 hex',
                                     { 'pixi.lock' => "version: 6\npackages:\n" . join('', map { "- name: p$_\n  md5: $sha\n" } 1 .. 250) }, 0, 'looks like row-level data'],
  ['other refused files get no lock-file note',
                                     { 'results/rows.json' => "[\n$json_recs\n]\n", 'results.lock' => "[\n$json_recs\n]\n" }, 0, 'looks like row-level data', 'A lock file:'],
  ['the lock-file note comes once, after the file\'s last finding',
                                     { 'poetry.lock' => $uv_big =~ s/name = "p1"/name = "p$mrn"/r },
                                     0, qr/MRN-like[^\n]*\n  poetry\.lock: [^\n]*row-level[^\n]*\n    \(A lock file:(?![\s\S]*A lock file:)/],
  ['each refused lock file gets its own note',
                                     { 'poetry.lock' => $uv_big, 'sub/pdm.lock' => $uv_big },
                                     0, qr/lock: [^\n]*\n    \(A lock file:[\s\S]*lock: [^\n]*\n    \(A lock file:/],
  ['a refused pixi.lock gets the lock-file note',
                                     { 'pixi.lock' => "version: 6\npackages:\n- conda: https://conda.example.org/libx-$day.0-0.conda\n" }, 0, 'never add phi-ok to it'],
  ['a refused package-lock.json gets the lock-file note',
                                     { 'package-lock.json' => "{\n  \"note\": \"$mrn\"\n}\n" }, 0, 'never add phi-ok to it'],
  ['a longer name or another letter case gets no lock-file note',
                                     { 'results/myuv.lock' => "[\n$json_recs\n]\n", 'UV.LOCK' => "[\n$json_recs\n]\n" }, 0, 'looks like row-level data', 'A lock file:'],
  ['pixi sha256 lines must be exactly 64 hex',
                                     { 'pixi.lock' => "version: 6\npackages:\n" . join('', map { "- name: p$_\n  sha256: " . substr($sha, 0, 40) . "\n" } 1 .. 250) }, 0, 'looks like row-level data'],
  ['pixi pypi references are not records',
                                     { 'pixi.lock' => "version: 6\nenvironments:\n  e1:\n    packages:\n      linux-64:\n" . join('', map { "      - pypi: https://files.example.org/p$_-1.0.whl\n" } 1 .. 250) }, 1],
  ['pixi checksum lines with Windows line endings count',
                                     { 'pixi.lock' => "version: 6\npackages:\n$pixi_pkgs" =~ s/\n/\r\n/gr }, 1],
  ['a git line without uv\'s source = { git = form does not count',
                                     { 'uv.lock' => $uv_head . join('', map { "\n[[package]]\nname = \"g$_\"\nversion = \"1.0\"\nnote = \"https://github.com/example/g$_#" . substr($sha, 0, 40) . "\"\ndependencies = [\n    { name = \"a\" },\n    { name = \"b\" },\n    { name = \"c\" },\n]\n" } 1 .. 120) }, 0, 'looks like row-level data'],
  ['the footer says assistants add phi-ok only as AGENTS.md allows',
                                     { 'docs/notes.md' => "size = $mrn\n" }, 0, 'only as AGENTS.md allows'],
  ['phi-ok on a line skips the PHI patterns on that line',
                                     { 'docs/notes.md' => "size = $mrn <!-- phi-ok -->\n" }, 1],
  ['the lock-file note links the template README',
                                     { 'poetry.lock' => $uv_big }, 0, 'project-template#lock-files-and-the-phi-check'],
  ['every known lock-file name gets the note',
                                     { map { ($_ => "{\n  \"note\": \"$mrn\"\n}\n") } qw(composer.lock Pipfile.lock yarn.lock Cargo.lock Gemfile.lock mix.lock flake.lock bun.lock npm-shrinkwrap.json packages.lock.json pnpm-lock.yaml conda-lock.yml) },
                                     0, qr/(?:\(A lock file:[\s\S]*){12}/],
  ['renv.lock URL lines inside Packages are checked',
                                     { 'renv.lock' => $renv_ok =~ s/      "Version": "1\.0",/      "Version": "1.0",\n      "x": [\n        "URL": "https:\/\/example.org\/$iso"\n      ],/r }, 0, 'full date'],
  # renv.lock: package descriptions and repository addresses pass; nothing else.
  ['renv.lock package descriptions and snapshot URLs pass',
                                     { 'renv.lock' => $renv_ok, 'sub/renv.lock' => $renv_ok =~ s/\n/\r\n/gr }, 1],
  ['renv.lock that starts another way gets every check',
                                     { 'renv.lock' => "\n$renv_ok" }, 0, 'MRN-like'],
  ['renv package text under another name gets every check',
                                     { 'renv.lock.bak' => $renv_ok, 'renv.json' => $renv_ok }, 0, 'MRN-like'],
  ['renv.lock MRN in a key fails',   { 'renv.lock' => $renv_ok =~ s/"Hash"/"$mrn"/r }, 0, 'MRN-like'],
  ['renv.lock MRN in the header fails',
                                     { 'renv.lock' => $renv_ok =~ s/"Version": "4\.4\.2"/"Version": "$mrn"/r }, 0, 'MRN-like'],
  ['renv.lock text at another depth gets every check',
                                     { 'renv.lock' => $renv_ok =~ s/^      "Description"/        "Description"/mr }, 0, 'MRN-like'],
  ['renv.lock MRN in an array fails', { 'renv.lock' => $renv_ok =~ s/        "R"\n/        "$mrn"\n/r }, 0, 'MRN-like'],
  ['renv.lock header URL that is not a web address fails',
                                     { 'renv.lock' => $renv_ok =~ s{"https://packagemanager\.posit\.co/cran/$iso"}{"$mrn"}r }, 0, 'MRN-like'],
  ['renv.lock text after the Packages section fails',
                                     { 'renv.lock' => $renv_ok =~ s/\}\n\}\n$/},\n  "Notes": {\n      "x": "$mrn"\n  }\n}\n/r }, 0, 'MRN-like'],
  ['renv.lock with only the first line wrong gets every check',
                                     { 'renv.lock' => $renv_ok =~ s/^\{/[/r }, 0, 'MRN-like'],
  ['renv.lock with only the second line wrong gets every check',
                                     { 'renv.lock' => $renv_ok =~ s/^  "R": \{/  "r": {/mr }, 0, 'MRN-like'],
  ['RENV.lock gets every check',     { 'RENV.lock' => $renv_ok }, 0, 'MRN-like'],
  ['myrenv.lock gets every check',   { 'myrenv.lock' => $renv_ok }, 0, 'MRN-like'],
  ['renv.lock local install folder is checked',
                                     { 'renv.lock' => $renv_ok =~ s/      "Version": "1\.0",/      "Version": "1.0",\n      "RemoteUrl": "\/home\/ann\/MRN_$mrn\/pkg",/r }, 0, 'MRN-like'],
  ['renv.lock text value with an escaped quote is blanked whole',
                                     { 'renv.lock' => $renv_ok =~ s/See doi/See \\"x\\" doi/r }, 1],
  ['renv.lock header URL at another depth is checked',
                                     { 'renv.lock' => $renv_ok =~ s/        "URL": "https/      "URL": "https/r }, 0, 'full date'],
  ['renv.lock header field other than URL is checked',
                                     { 'renv.lock' => $renv_ok =~ s/        "URL": "https/        "Site": "https/r }, 0, 'full date'],
  ['renv.lock header URL with a login is checked',
                                     { 'renv.lock' => $renv_ok =~ s{https://packagemanager}{https://$email/packagemanager}r }, 0, 'email'],
  ['renv.lock http header URL is checked',
                                     { 'renv.lock' => $renv_ok =~ s{"https://packagemanager}{"http://packagemanager}r }, 0, 'full date'],
  ['renv.lock URL lines after the Packages section are checked',
                                     { 'renv.lock' => $renv_ok =~ s/\}\n\}\n$/},\n  "Notes": [\n      {\n        "URL": "https:\/\/example.org\/$iso"\n      }\n  ]\n}\n/r }, 0, 'full date'],
  ['renv.lock local paths are checked whatever the key',
                                     { 'renv.lock' => $renv_ok =~ s/      "Version": "1\.0",/      "Version": "1.0",\n      "RemotePkgRef": "local::\/home\/ann\/MRN_$mrn\/pkg",/r }, 0, 'MRN-like'],
  ['renv.lock Windows paths are checked whatever the key',
                                     { 'renv.lock' => $renv_ok =~ s/      "Version": "1\.0",/      "Version": "1.0",\n      "Source": "C:\\\\Users\\\\ann\\\\$mrn",/r }, 0, 'MRN-like'],
  ['renv.lock: a relative RemoteUrl is checked, with the lock-file note',
                                     { 'renv.lock' => $renv_ok =~ s{      "Version": "1\.0",}{      "Version": "1.0",\n      "RemoteUrl": "pkgs/MRN_$mrn",}r }, 0, qr/MRN-like[\s\S]*never add phi-ok to it/],
  ['renv.lock: a / path is checked',
                                     { 'renv.lock' => $renv_ok =~ s{      "Version": "1\.0",}{      "Version": "1.0",\n      "RemotePkgRef": "/home/a/$mrn",}r }, 0, 'MRN-like'],
  ['renv.lock: a ~ path is checked',
                                     { 'renv.lock' => $renv_ok =~ s{      "Version": "1\.0",}{      "Version": "1.0",\n      "RemotePkgRef": "~/a/$mrn",}r }, 0, 'MRN-like'],
  ['renv.lock: a file: path is checked',
                                     { 'renv.lock' => $renv_ok =~ s{      "Version": "1\.0",}{      "Version": "1.0",\n      "RemotePkgRef": "file:///a/$mrn",}r }, 0, 'MRN-like'],
  ['renv.lock: a network share is checked',
                                     { 'renv.lock' => $renv_ok =~ s{      "Version": "1\.0",}{      "Version": "1.0",\n      "RemotePkgRef": "\\\\srv\\\\a\\\\$mrn",}r }, 0, 'MRN-like'],
  ['records saved as renv.lock with renv header still fail',
                                     { 'renv.lock' => "$renv_head  \"Packages\": [\n$json_recs\n  ]\n}\n" }, 0, 'looks like row-level data'],
  ['provenance tokens do not count as package checksums',
                                     { 'uv.lock' => "version = 1\n[\n$token_json\n]\n" }, 0, 'looks like row-level data'],
  ['only uv.lock and pixi.lock, by exact name, get the allowance',
                                     { 'renv.lock' => $uv_big }, 0, 'looks like row-level data'],
  ['a longer name ending in uv.lock gets every check',
                                     { 'myuv.lock' => $uv_big }, 0, 'looks like row-level data'],
  ['a copy named uv.lock.bak gets every check',
                                     { 'uv.lock.bak' => $uv_big }, 0, 'looks like row-level data'],
  ['a dotted key ending in a checksum name does not count',
                                     { 'uv.lock' => "version = 1\n[\n$hashed_dots\n]\n" }, 0, 'looks like row-level data'],
  ['a key ending in a checksum name does not count',
                                     { 'sub/pixi.lock' => "version: 6\npackages:\n$hashed_yaml" }, 0, 'looks like row-level data'],
  ['records with too few checksums fail',
                                     { 'uv.lock' => "version = 1\nsdist = { hash = \"sha256:$sha\" }\n[\n$json_recs\n]\n" }, 0, 'looks like row-level data'],
  ['checksums all on one line do not count',
                                     { 'uv.lock' => "version = 1\nnote = [" . join(' ', ("{ hash = \"sha256:$sha\" }") x 150) . "]\n[\n$json_recs\n]\n" }, 0, 'looks like row-level data'],
  ['HTML table rows under a lock file name fail',
                                     { 'uv.lock' => "version = 1\n# $sha\n<table>\n" . join('', map { "<tr><td>p$_</td></tr>\n<!-- $sha -->\n" } 1 .. 250) . "</table>\n" }, 0, 'HTML table rows'],
  ['pixi environment references are not records',
                                     { 'pixi.lock' => "version: 6\nenvironments:\n" . join('', map { my $e = $_; "  e$e:\n    packages:\n      linux-64:\n" . join('', map { "      - conda: https://conda.example.org/p$_-1.0.conda\n" } 1 .. 60) } 1 .. 5) . "packages:\n- conda: https://conda.example.org/p1-1.0.conda\n  sha256: $sha\n" }, 1],
  ['a lock file name in other case gets the record counts',
                                     { 'UV.LOCK' => $uv_big }, 0, 'looks like row-level data'],
  ['sizes in other files fail',      { 'docs/notes.md' => "size = $mrn\n", 'results/out.yml' => "  timestamp: $mrn\n" }, 0, 'MRN-like'],
);

my ($pass, $fail) = (0, 0);
for my $c (@cases) {
  # $msg: text (or a qr// pattern) the message must hold; $not: text it must not.
  my ($name, $files, $want, $msg, $not) = @$c;
  my $dir = tempdir(CLEANUP => 1);
  run($dir, 'git', 'init', '-q');
  mkdir "$dir/tools";
  write_file("$dir/tools/phi_guard.pl", slurp($guard));
  write_file("$dir/$_", $files->{$_}) for keys %$files;
  run($dir, 'git', 'add', '-A');
  my $out = `cd "$dir" && perl tools/phi_guard.pl --all 2>&1`;
  my $ok = $? == 0 ? 1 : 0;
  my $good = $ok == $want && (!defined $msg || (ref $msg ? $out =~ $msg : index($out, $msg) >= 0))
             && (!defined $not || index($out, $not) < 0);
  if ($good) { $pass++; print "ok   $name\n" }
  else { $fail++; print "FAIL $name (exit " . ($ok ? 0 : 1) . ")\n" . ($out =~ s/^/     /mgr) . ($out =~ /\n\z/ ? '' : "\n") }
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

#!/usr/bin/env perl
# Lab core: identical in every lab repository; change it in
# vlmurthylab/project-template. Per-repository settings are in phi-guard.conf.
#
# Checks what is about to be committed (or everything in the repository) for
# subject-level data and things that look like PHI. Run by hooks/pre-commit
# and by the GitHub check in .github/workflows/phi-check.yml.
#
#   perl tools/phi_guard.pl --staged   files staged for the next commit
#   perl tools/phi_guard.pl --all      every file in the repository
#
# It refuses:
#   - data file types (CSV, Excel, .rds, .parquet, DICOM, ...), even if they
#     were force-added past .gitignore. Allowed: .csv/.tsv in reference/ and
#     results/tables/;
#   - compressed files, model weights, R Notebook (.nb.html) files, and
#     knitr/Quarto caches;
#   - anything in data/ (except data/README.md) or in a phi/ folder;
#   - secrets and files that reveal real paths: .env, .Renviron, .pgpass,
#     credentials, tokens, private keys (by name or by a -----BEGIN ... PRIVATE
#     KEY----- block in any file), salts, checksum manifests and path maps; files
#     matching BLOCK_FILES (this repository's own never-commit list);
#   - files larger than LARGE_FILE_MB;
#   - text that looks like PHI: SSNs, MRN-like numbers (7+ digits), phone
#     numbers everywhere; email addresses in notes and outputs; full dates
#     only in outputs (notebooks, tables, HTML, text), not in code or notes;
#   - counts below MIN_CELL in summary tables, if MIN_CELL is set;
#   - row-level data even when it has no identifiers (for example de-identified
#     cohort study data), in any file that is not code: long runs of rows that
#     look like a table (delimited or printed), long lists of records or values
#     (JSON, dput(), HTML tables, YAML), tables with a participant ID column
#     (ID_COLUMNS), and notebooks saved with outputs.
# Settings are in phi-guard.conf. The PHI patterns follow R/check_outputs.R in
# um-nuc-cardiology-registry.
#
# Escapes: a line containing the text phi-ok is skipped by the PHI patterns
# (put it in a comment). Files matching ALLOW_FILES (for example a large
# published reference table) skip the file-type, PHI and row-level checks;
# they never override the never-commit lists above.
#
# Uses only Perl's standard library: Perl comes with Git for Windows and macOS.

use strict;
use warnings;
use Encode ();

my $mode = shift // '';
die "usage: perl tools/phi_guard.pl --staged | --all\n"
  unless $mode eq '--staged' || $mode eq '--all';

chomp(my $root = `git rev-parse --show-toplevel`);
die "phi_guard: not inside a git repository\n" if $? != 0;
chdir $root or die "phi_guard: cannot enter $root\n";

# ---- Settings ----
my %conf = (MIN_CELL => 0, COUNT_COLUMNS => 'n,count', LARGE_FILE_MB => 10, ALLOW_FILES => '', BLOCK_FILES => '',
            MAX_TABLE_ROWS => 200,
            ID_COLUMNS => 'id,idno,id_c,short_id,pid,iid,fid,seqn,eid,shareid,mrn,subjid,subject_id,subjectid,'
                        . 'participant_id,patient_id,person_id,sample_id,study_id,record_id,dbgap_subject_id');
if (open my $fh, '<', 'phi-guard.conf') {
  while (<$fh>) {
    s/\r?\n$//;
    next if /^\s*(#|$)/;
    $conf{$1} = $2 if /^\s*(\w+)\s*=\s*(.*?)\s*$/;
  }
}
for my $k (qw(MIN_CELL LARGE_FILE_MB MAX_TABLE_ROWS)) {
  die "phi_guard: $k in phi-guard.conf must be a whole number\n" unless $conf{$k} =~ /^\d+$/;
}
my %count_col = map { lc($_) => 1 } grep { length } split /\s*,\s*/, $conf{COUNT_COLUMNS};
my %id_col    = map { lc($_) => 1 } grep { length } split /\s*,\s*/, $conf{ID_COLUMNS};

# File patterns (ALLOW_FILES, BLOCK_FILES, the lists below) work like
# .gitignore: * matches within a folder, **/ any number of folders (including
# none), ? one character; a trailing / means a folder and everything in it; a
# pattern with no / except a trailing one matches that name in any folder; a
# leading / anchors it to the top of the repository.
# ALLOW_FILES: an exact path (a full path from the top, with no wildcards or
# trailing /) skips the file-type, PHI and row-level checks; a folder, a glob
# or a bare name skips only the PHI and row-level checks, so data file types,
# compressed files, model weights and caches are still refused. Neither overrides data/,
# phi/, .env, the never-commit lists or the size limit.
sub glob_re {
  my ($g, $nocase) = @_;
  my $anchored = $g =~ s{^/}{};
  my $dir = $g =~ s{/$}{};
  my $re = join '', map {
    $_ eq '**/' ? '(?:.*/)?' : $_ eq '**' ? '.*' : $_ eq '*' ? '[^/]*' : $_ eq '?' ? '[^/]' : quotemeta
  } split m{(\*\*/|\*\*|\*|\?)}, $g;
  $re .= '/.*' if $dir;
  $re = ($anchored || $g =~ m{/}) ? "^$re\$" : "(?:^|/)$re\$";
  return $nocase ? qr/$re/i : qr/$re/;
}
my @allow_items = grep { length } split /\s*,\s*/, $conf{ALLOW_FILES};
my %allow_exact = map { s{^/}{}r => 1 } grep { m{/.} && !m{[*?]|/$} } @allow_items;
my @allow_re = map { glob_re($_) } grep { !(m{/.} && !m{[*?]|/$}) } @allow_items;
sub allowed { my ($f) = @_; return 2 if $allow_exact{$f}; for (@allow_re) { return 1 if $f =~ $_ } 0 }

# Never committed, in any lab repository: secrets, and files that list real
# paths (which can hold names and MRNs). BLOCK_FILES adds this repository's own
# (paths, folders ending in /, or globs; a name without / matches anywhere).
# ALLOW_FILES cannot override either list.
# Names are matched in any folder and in any letter case. Kept narrow (by
# extension) so code and docs about these things, like R/secrets.R, are not
# caught: ALLOW_FILES cannot release a file from this list.
my @core_block = map { glob_re($_, 1) } (
  '.Renviron', '.pgpass', '.netrc', '.httr-oauth', '.git-credentials', '.aws/', '.ssh/', 'secrets/', 'credentials/',
  'id_rsa*', 'id_ecdsa*', 'id_ed25519*', '*.pem', '*.p12', '*.pfx', '*.ppk', '*.keystore', '*.jks', 'client_secret*.json',
  (map { ("credentials.$_", "secrets.$_") } qw(json csv txt ini cfg yml yaml toml env)), 'credentials', 'secrets',
  'salt', '*.salt', 'SHA256SUMS', 'SHA256SUMS*.txt', '*.md5', '*.sha256', 'upstream-checksums', 'upstream-checksums*.txt',
  'STAT.baseline', (map { "pathmap*.$_" } qw(tsv csv txt)));
# Matched without regard to case, like the list above: exports from Windows
# often have upper-case extensions (A.XML). ALLOW_FILES stays exact.
my @repo_block = map { glob_re($_, 1) } grep { length } split /\s*,\s*/, $conf{BLOCK_FILES};

# ---- Rules ----
my $DATA_EXT = qr/\.(csv|tsv|xlsx?|xlsm|ods|parquet|feather|arrow|fst|sav|dta|sas7bdat|xpt|sqlite3?|db|duckdb
                    |rds|rda|rdata|rdb|rdx|qs|pkl|pickle|npy|npz|h5|hdf5|mat|dcm|nii|edf|hea|dat|dump|backup)$/xi;
# Model weights: models trained on protected data can memorize it, and data use
# agreements often cover derived models. Weights the agreements allow to be
# released go to a model hub (the lab's Hugging Face organization), not git.
my $WEIGHTS  = qr/\.(pt|pth|ckpt|safetensors|onnx|joblib|keras|tflite|gguf|bin|pb|msgpack|mlmodel|params|pdparams)$/i;
my $PACKED   = qr/\.(zip|gz|tgz|bz2|xz|zst|7z|rar|tar)$/i;   # can hide anything
my $CODE_EXT = qr/\.(r|py|sql|sh|ps1|bat|jl|m|js|ts|c|cc|cpp|h|java|go|rs|do|sas|sbatch|slurm|yml|yaml|toml)$/i;
my $ROW_SKIP = qr/\.(r|py|sql|sh|ps1|bat|jl|m|js|ts|c|cc|cpp|h|java|go|rs|do|sas|sbatch|slurm|svg|eps|ps)$/i;  # hand-written code; vector figures
# Dependency lock files, by exact name: lists of software packages whose many
# '}, {' entries look like data records. They skip only the record and list
# counts below; every other check still applies.
my $LOCKFILE = qr{(?:^|/)(?:uv|poetry|renv|Pipfile|yarn|pixi|Cargo|Gemfile|composer|flake|bun|pdm|mix)\.lock$
                 |(?:^|/)(?:package-lock|npm-shrinkwrap|packages\.lock)\.json$
                 |(?:^|/)(?:pnpm-lock|conda-lock)\.ya?ml$}xi;
my $NOTE_EXT = qr/\.(md|markdown|rmd|qmd|rst|tex|bib|cff)$/i;   # notes and documents you write
my $SKIP_EXT = qr/\.(png|jpe?g|gif|tiff?|bmp|ico|pdf|woff2?|ttf|otf|eot)$/i;

my %PATTERNS = (
  'an SSN'             => qr/\b\d{3}-\d{2}-\d{4}\b/,
  'an MRN-like number' => qr/(?<![\w.,])\d{7,}(?![\w.,])/,
  'a phone number'     => qr/\(?\b\d{3}\)?[-. ]\d{3}[-. ]\d{4}\b/,
  'an email address'   => qr/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/,
  'a full date (ISO)'  => qr/\b(?:19|20)\d{2}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])\b/,
  'a full date (US)'   => qr{\b(?:0?[1-9]|1[0-2])/(?:0?[1-9]|[12]\d|3[01])/(?:19|20)?\d{2}\b},
);
my @CODE_PATTERNS = ('an SSN', 'an MRN-like number', 'a phone number');
my @NOTE_PATTERNS = (@CODE_PATTERNS, 'an email address');
my @ALL_PATTERNS  = (@NOTE_PATTERNS, 'a full date (ISO)', 'a full date (US)');

# ---- Files to check ----
my @files;
{
  local $/ = "\0";
  my @cmd = $mode eq '--staged' ? qw(git diff --cached --name-only --diff-filter=ACMR -z) : qw(git ls-files -z);
  open my $g, '-|', @cmd or die;
  @files = map { chomp; $_ } <$g>;
}

sub content {           # the version being committed, or the file on disk
  my ($f) = @_;
  my $c;
  if ($mode eq '--staged') {
    open my $g, '-|', 'git', 'show', ":$f" or return '';
    binmode $g; local $/; $c = <$g>;
  } else {
    open my $fh, '<', $f or return '';
    binmode $fh; local $/; $c = <$fh>;
  }
  $c //= '';
  # UTF-16 text (Excel "Unicode Text", Windows PowerShell redirection) would
  # otherwise look binary and skip every check.
  if    ($c =~ /^\xFF\xFE/) { $c = Encode::encode('UTF-8', Encode::decode('UTF-16LE', substr($c, 2))) }
  elsif ($c =~ /^\xFE\xFF/) { $c = Encode::encode('UTF-8', Encode::decode('UTF-16BE', substr($c, 2))) }
  $c =~ s/^\xEF\xBB\xBF//;   # UTF-8 byte-order mark (Excel "CSV UTF-8")
  return $c;
}

sub size_bytes {
  my ($f) = @_;
  if ($mode eq '--staged') { chomp(my $s = `git cat-file -s ":$f"`); return $s || 0 }
  return -s $f // 0;
}

my $N = $conf{MAX_TABLE_ROWS};
my @problems;

for my $f (@files) {
  next if $f =~ m{^(hooks/|tools/phi_guard\.pl$)};
  my $ok = allowed($f);

  # File types and places that never belong in git.
  if ($f =~ m{^data/} && $f ne 'data/README.md') { push @problems, "$f: files in data/ are never committed"; next }
  if ($f =~ m{(^|/)phi/})                       { push @problems, "$f: files in a phi/ folder are never committed"; next }
  if ($f =~ m{(^|/)\.env(\.|$)})                { push @problems, "$f: .env files hold local settings and secrets"; next }
  if (grep { $f =~ $_ } @core_block) { push @problems, "$f: secrets, checksum manifests and path maps are never committed"; next }
  if (grep { $f =~ $_ } @repo_block) { push @problems, "$f: on this repository's never-commit list (BLOCK_FILES in phi-guard.conf)"; next }
  unless ($ok == 2) {
    my $allowed_table = $f =~ m{^(reference|results/tables)/.*\.(csv|tsv)$}i;
    if ($f =~ $DATA_EXT && !$allowed_table) {
      push @problems, "$f: data file type (only .csv/.tsv in reference/ and results/tables/ are allowed)"; next;
    }
    if ($f =~ $PACKED) { push @problems, "$f: compressed file; it can hold data the check cannot see"; next }
    if ($f =~ $WEIGHTS) { push @problems, "$f: model weights; they stay on lab storage, and models the data use agreement allows to be released go on the lab's Hugging Face, not in git"; next }
    if ($f =~ /\.nb\.html$/i || $f =~ m{(^|/)(_freeze|[^/]*_cache)/}) {
      push @problems, "$f: R Notebook, knitr cache or Quarto freeze file; these store results computed from the data"; next;
    }
  }
  my $mb = size_bytes($f) / 1048576;
  if ($conf{LARGE_FILE_MB} > 0 && $mb > $conf{LARGE_FILE_MB}) {
    push @problems, sprintf("%s: %.1f MB is over LARGE_FILE_MB (%s); large files usually hold data", $f, $mb, $conf{LARGE_FILE_MB});
    next;
  }

  my $text = $f =~ $SKIP_EXT ? '' : content($f);
  # A private key is refused whatever the file is called (and ALLOW_FILES
  # cannot release it). Placeholder blocks in docs, with no key body, pass.
  if ($text =~ /-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----\s*[A-Za-z0-9+\/=]{20,}/) {
    push @problems, "$f: contains a private key; keys are never committed"; next;
  }
  next if $f =~ $SKIP_EXT || $ok;
  next if substr($text, 0, 8000) =~ /\0/;      # binary
  # Embedded images and fonts (base64 data URIs) cannot hold readable data but
  # look like digit runs; in HTML, scripts and styles (jQuery, Bootstrap) look
  # like data too. Drop them, but keep JSON data blocks (htmlwidgets, plotly),
  # which can hold real data.
  $text =~ s{data:[\w/+.-]+;base64,[A-Za-z0-9+/=]+}{data:}g;
  if ($f =~ /\.html?$/i) {
    $text =~ s{<script\b(?![^>]*application/json)[^>]*>.*?</script>}{}gis;
    $text =~ s{<style\b[^>]*>.*?</style>}{}gis;
  }
  my @lines = split /\r\n?|\n/, $text;          # Windows, old Mac and Unix line endings

  # PHI-looking text: the first hit of each pattern in each file.
  # Code and notes are written by hand, where dates are usually harmless (a
  # cutoff date, a dated plan); outputs and anything else get every pattern.
  my @pats = $f =~ $CODE_EXT ? @CODE_PATTERNS : $f =~ $NOTE_EXT ? @NOTE_PATTERNS : @ALL_PATTERNS;
  my %seen;
  for my $i (0 .. $#lines) {
    my $line = $lines[$i];
    next if $line =~ /phi-ok/;
    next if $line =~ m{"image/(png|jpeg|gif|svg\+xml)"};   # notebook plot data
    for my $p (@pats) {
      next if $seen{$p};
      if ($line =~ $PATTERNS{$p}) { push @problems, sprintf("%s:%d: looks like %s", $f, $i + 1, $p); $seen{$p} = 1 }
    }
  }

  # Row-level data, which may carry no identifiers at all (de-identified cohort
  # data is IDs and measurements). Hand-written code and vector figures are skipped.
  unless ($f =~ $ROW_SKIP) {
    my @found;

    # Notebooks must be committed with outputs cleared.
    push @found, "$f: notebook saved with outputs; clear them before committing (for example with nbstripout)"
      if $f =~ /\.ipynb$/i && $text =~ /"outputs"\s*:\s*\[\s*[^\]\s]/;

    my ($rtext, @rlines) = ($text, @lines);

    if ($N > 0) {
      # Long runs of lines that look like rows of one table: the same number of
      # delimiters (quoted fields removed first, so "HTN, DM" doesn't break the
      # run; a single delimiter counts only if a field is a number, so two-column
      # tables are caught but prose and .bib entries are not), or lines that are
      # mostly numbers (printed data frames, .Rout and .log output, fixed-width
      # text), whose word counts may vary.
      my (%run, %prev);   # shape => [run length, first line of run]
      my ($best, $best_at, $best_kind) = (0, 0, '');
      my $num = qr/^\s*[-+]?(?:\d[\d.,]*|\.\d+)(?:[eE][-+]?\d+)?%?\s*$/;
      for my $i (0 .. $#rlines) {
        last if $best > $N;
        my $l = $rlines[$i] =~ s/"(?:[^"\\]|""|\\.)*"/Q/gr;
        my %shape;
        my %k = (',' => ($l =~ tr/,//), "\t" => ($l =~ tr/\t//), '|' => ($l =~ tr/|//), ';' => ($l =~ tr/;//));
        for my $d (',', "\t", '|', ';') {
          my $k = $k{$d};
          $shape{$d} = $k if $k >= 2 || ($k == 1 && grep { $_ =~ $num } split /\Q$d\E/, $l);
        }
        my @tok = split ' ', $l;
        $shape{ws} = 1 if @tok >= 3 && (grep { $_ =~ $num || $_ eq 'NA' } @tok) * 2 >= @tok;
        for my $s (',', "\t", '|', ';', 'ws') {
          if (defined $shape{$s} && defined $prev{$s} && $shape{$s} == $prev{$s}) { $run{$s}[0]++ }
          elsif (defined $shape{$s}) { $run{$s} = [1, $i + 1] }
          else { delete $run{$s} }
          if ($run{$s} && $run{$s}[0] > $best) { ($best, $best_at, $best_kind) = (@{ $run{$s} }, $s) }
        }
        %prev = %shape;
      }
      if ($best > $N) {
        my $name = { ',' => 'comma-separated', "\t" => 'tab-separated', '|' => 'pipe-separated',
                     ';' => 'semicolon-separated', ws => 'printed (space-aligned)' }->{$best_kind};
        push @found, "$f:$best_at: $best rows of $name values from here; looks like row-level data (over MAX_TABLE_ROWS, $N)";
      }

      # Data that is not one row per line: lists of records (JSON, YAML),
      # HTML table rows (knitted reports), and long value lists (dput(), dump(),
      # column-wise JSON, embedded widget data).
      # (Notebooks are skipped here: their cells are JSON records, and the
      # outputs check above covers what they can leak.)
      my %count;
      unless ($f =~ /\.ipynb$/i || $f =~ $LOCKFILE) {
        %count = (
          'JSON records'      => scalar(() = $rtext =~ /\}\s*,\s*\{/g),
          'JSON array rows'   => scalar(() = $rtext =~ /\]\s*,\s*\[/g),
          'HTML table rows'   => scalar(() = $rtext =~ /<tr\b/gi),
          'YAML list records' => scalar(() = $rtext =~ /^\s*-\s+[\w"']+\s*:/mg),
        );
        my $longest = 0;
        while ($rtext =~ /(?<![\w.])((?:\s*+(?:"[^"\n]{0,80}"|-?[\w.]++)\s*+,){50,})/g) {
          my $k = $1 =~ tr/,//;
          $longest = $k if $k > $longest;
        }
        $count{'values in one list'} = $longest;
      }
      for my $what (sort keys %count) {
        if ($count{$what} > $N) {
          push @found, "$f: $count{$what} $what; looks like row-level data (over MAX_TABLE_ROWS, $N)";
          last;
        }
      }
    }

    # A participant ID column means one row per person.
    my ($first) = grep { /\S/ } @lines;
    if (defined $first) {
      for my $d (',', "\t", '|', ';') {
        next unless $first =~ /\Q$d\E/;
        my @ids = grep { $id_col{ lc $_ } } map { s/^\s*"|"\s*$//gr =~ s/^\s+|\s+$//gr } split /\Q$d\E/, $first, -1;
        if (@ids) { push @found, "$f:1: has an ID column ('$ids[0]'); tables with participant IDs are row-level data"; last }
      }
    }
    push @problems, @found;
  }

  # Small counts in summary tables.
  if ($conf{MIN_CELL} > 0 && $f =~ m{^results/tables/[^/]+\.(csv|tsv)$}i && @lines) {
    my $sep = $f =~ /\.tsv$/i ? "\t" : ',';
    my @head = map { s/^"|"$//gr } split /\Q$sep\E/, $lines[0], -1;
    my @cols = grep { $count_col{ lc $head[$_] } } 0 .. $#head;
    ROW: for my $i (1 .. $#lines) {
      next if $lines[$i] =~ /phi-ok/;
      my @v = map { s/^"|"$//gr } split /\Q$sep\E/, $lines[$i], -1;
      for my $c (@cols) {
        my $x = ($v[$c] // '') =~ s/,//gr;
        if ($x =~ /^\d+$/ && $x > 0 && $x < $conf{MIN_CELL}) {
          push @problems, sprintf("%s:%d: count %s in column '%s' is below MIN_CELL (%s)", $f, $i + 1, $x, $head[$c], $conf{MIN_CELL});
          last ROW;
        }
      }
    }
  }
}

exit 0 unless @problems;

print STDERR "phi-guard: stopped. These look like data or PHI:\n";
print STDERR "  $_\n" for @problems;
print STDERR <<'EOT';

Remove them, or move the data to lab storage. Then:
  - "looks like" a PHI pattern, but the line isn't about a person (a random
    seed, a published sample size): add the text phi-ok in a comment on that
    line, and say so in the commit message;
  - a notebook with outputs: clear them (for example with nbstripout);
  - a large published table that is not about individuals (a lookup table,
    genome-wide summary statistics): ask Venk to list it in ALLOW_FILES in
    phi-guard.conf.
Questions: #vlmurthylab-github.
EOT
exit 1;

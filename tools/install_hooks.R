# Lab core: identical in every lab repository; change it in
# vlmurthylab/project-template.
#
# Turns on the PHI check for this copy of the repository. Run once per clone,
# from R with the repository as the working directory (e.g. an RStudio project):
#
#   source("tools/install_hooks.R")
#
# or, in a terminal from the repository folder:
#
#   git config core.hooksPath hooks
#
# Git then runs hooks/pre-commit directly, so later updates to the hook take
# effect without reinstalling.

status <- system2("git", c("config", "core.hooksPath", "hooks"))
if (!identical(status, 0L)) stop("git config failed; run this from the repository folder.")
message("PHI check on: git will run hooks/pre-commit on every commit.")

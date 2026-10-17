#' Fast read wrapper for multiple objects using qs
#'
#' This reads output of mqsave which wraps objects in a list to allow saving multiple objects using qs
#'
#' @param fname filename of a file written by mqsave
#' @param ... additional parameters passed to qs::qread
#' @return called for its side effect of restoring the saved objects into the calling environment
#' @keywords serialization fast save
#' @examples
#' \dontrun{
#' test.data <- data.frame(var1=rnorm(1000), var2=rnorm(1000))
#' mqsave(objects="test.data",fname="test.qs")
#' rm(test.data)
#' mqread(fname="test.qs")
#' }
#' @export

mqread <- function(fname, ...) {
  # Call qread
  object.list <- qs::qread(file=fname, ...)

  # Unlist objects
  for(x in names(object.list)) assign(x,object.list[[x]],envir=parent.frame())
}

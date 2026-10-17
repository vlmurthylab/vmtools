#' Fast save wrapper for multiple objects using qs
#'
#' This function wraps multiple objects into a list to allow saving using qs
#'
#' @param objects vector containing names of objects to save
#' @param fname filename
#' @param ... additional parameters passed to qsave
#' @return returns result of qsave call from qs module
#' @keywords serialization fast save
#' @examples
#' \dontrun{
#' test.data <- data.frame(var1=rnorm(1000), var2=rnorm(1000))
#' mqsave(objects="test.data",fname="test.qs")
#' rm(test.data)
#' mqread(fname="test.qs")
#' }
#' @export

mqsave <- function(objects, fname, ...) {
  # Package all objects into a list
  object.list <- lapply(objects, get, envir = parent.frame())
  names(object.list) <- objects

  # Call qsave
  qs::qsave(object.list, fname, ...)
}

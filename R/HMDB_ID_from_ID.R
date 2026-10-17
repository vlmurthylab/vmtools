#' Query Human Metabolome Database by HMDB ID
#'
#' This function searches the HMDB to find the canonical HMDB ID for a given ID.
#'
#' @param ids vector of strings with ID starting with "HMDB" or numbers with just the numeric part
#' @param max.tries number of times to retry loading a page
#' @return vector of strings with canonical HMDB IDs
#' @keywords HMDB
#' @examples
#' \dontrun{
#' HMDB_ID_from_ID(22)
#' HMDB_ID_from_ID("HMDB0006022")
#' HMDB_ID_from_ID("HMDB1162")
#'
#'id.list <- c("Internal Standard","Internal Standard","HMDB00123","HMDB00161","HMDB00187","HMDB00167",
#'             "HMDB00696","HMDB00148","HMDB00168","HMDB00641","HMDB00177","HMDB00517",
#'             "HMDB00182","HMDB00883","HMDB00687","HMDB00172","HMDB00159","HMDB00158",
#'             "HMDB00929","HMDB00162","HMDB00725","HMDB00214","HMDB00904","HMDB00251",
#'             "HMDB00112","HMDB00092","HMDB01539","HMDB03334","HMDB29416","HMDB01906*",
#'             "HMDB00715","HMDB00898","HMDB00026","HMDB00235","HMDB01406","HMDB00043",
#'             "HMDB00097","HMDB00086","HMDB00895","HMDB00064","HMDB00562","HMDB00248",
#'             "HMDB00925","HMDB00050","HMDB00630","HMDB00299","HMDB01046","HMDB00716",
#'             "HMDB00699","HMDB01161","HMDB02005","HMDB00062","HMDB00201","HMDB00824",
#'             "HMDB13133","HMDB02013","HMDB13127","HMDB00688","HMDB02366","HMDB13130",
#'             "HMDB00705","HMDB13238","HMDB00791","HMDB13288","HMDB00651","HMDB13325",
#'             "HMDB02250","HMDB13326","HMDB05066","HMDB02014","HMDB13331","HMDB00222",
#'             "HMDB00848","HMDB05065","HMDB06469","HMDB06347","HMDB11103","HMDB03331",
#'             "HMDB01563","HMDB04030","HMDB00991*","HMDB32390","HMDB05862",NA,
#'             "HMDB00479","HMDB03681","HMDB01867","HMDB03464","HMDB13678","HMDB04400",
#'             "HMDB00982","HMDB01182","HMDB00897","HMDB01859","HMDB00212","HMDB60994",
#'             "HMDB01008","HMDB01847","HMDB1162","HMDB00063","HMDB02802","HMDB31404")
#'
#' t0 <- Sys.time()
#' HMDB_ID_from_ID(id.list)
#' Sys.time() -t0
#' }
#' @export

HMDB_ID_from_ID <- function(ids,max.tries=5) {
  # Set up some search constants
  search.url <- "https://hmdb.ca/unearth/q?button=&page=%i&query=%s&searcher=metabolites"

  # Simplify list
  ids <-unlist(ids)

  # Remove trailing asterisks
  ids <- gsub("\\*$","",ids)

  # Initialize output list
  out.ids <- rep("",length(ids))
  names(out.ids) <- ids

  # Loop over all elements
  for (i in seq_along(ids)) {
    # Pull out one ID
    x <- ids[i]

    # It is a character string that starts with "HMDB" then fine, likewise if it is a number. Otherwise NA
    if (is.na(x)) {
      out.ids[i] <- NA
      next
    } else if (is.character(x) & substr(x,1,4)=="HMDB") { out.ids[i] <- x
    } else if (is.numeric(x)) { out.ids[i] <- sprintf("HMDB%07i",x)
    } else {
      out.ids[i] <- NA
      next
    }

    # Initialize good.q
    good.q <- FALSE

    # Set up a pause before reloading
    Sys.sleep(0.5)
    pause.length <- 5

    # Attempt counter
    num.tries <- 0

    # Repeatedly load, with longer and longer pauses if we fail
    repeat {
      # Retry pulling headers
      h <- httr::HEAD(sprintf(search.url,1,out.ids[i]))$all_headers

      # Find which is last element of chain which is status 302 (Found)
      list.302 <- which(sapply(h,FUN=function(x) x$status)==302)
      h.final <- ifelse(length(list.302)>0,max(list.302),NA)

      # Find final status
      final.status <- h[[length(h)]]$status

      # If we found a record
      if (!is.na(h.final) & is.finite(h.final) & final.status==200) {

        # pull out the location header
        l <- strsplit(h[[h.final]][["headers"]][["location"]],"\\/")
        l <- l[[1]][length(l[[1]])]

        # If it is appropriate new ID, then break, otherwise try again
        if (nchar(l)>=11 & substr(l,1,4)=="HMDB") {
          out.ids[i] <- l
          break
        }
      } else if (final.status==404) {
        out.ids[i] <- NA
        break
      } else {
        num.tries <- num.tries + 1
        if (num.tries > max.tries) {
          out.ids[i] <- NA
          break
        }
      }

      # Pause
      Sys.sleep(pause.length)

      # Increase next pause
      pause.length <- pause.length * 1.5
    }
  }

  return(out.ids)
}



###-------------
## methods
###------------- the "as.list", "rbind(a thin wrapper of bindROWS)"
### will realize all lazyIndexes and construct a new DelayedDataFrame
### (with initial lazyIndex of NULL).

setMethod("getListElement", "DelayedDataFrame", function(x, i, exact=TRUE)
{
    i2 <- normalizeDoubleBracketSubscript(
        i, x, exact = exact,
        allow.NA = TRUE,
        allow.nomatch = TRUE)
    if (is.na(i2)) 
        return(NULL)
    index <- .get_index(x, i2)
    elt <- x@listData[[i2]]
    if (!is.null(index))
        elt <- extractROWS(elt, index)
    elt
})

### "as.list" function is called in lapply("DelayedDataFrame", ) and
### names("DelayedDataFrame")...
#' @description DelayedDataFrame related methods. \code{as.list},
#'     \code{rbind} would incur realization.
#' @rdname DelayedDataFrame-method
#' @param x a \code{DelayedDataFrame} object.
#' @param use.names whether to use the colnames of
#'     \code{DelayedDataFrame} as the names for the returned list.
#' @aliases as.list,DelayedDataFrame-method
#' @exportMethod as.list
setMethod("as.list", "DelayedDataFrame", function(x, use.names=TRUE)  
{
    ans <- lapply(seq_along(x), function(j) x[[j]])
    if (use.names)
        names(ans) <- names(x)
    ans
})

#' @return colnames of \code{DelayedDataFrame}
#' @rdname DelayedDataFrame-method
#' @aliases names,DelayedDataFrame-method
#' @exportMethod names
setMethod("names", "DelayedDataFrame", function(x)
{
    names(x@listData)
})

#' \code{cbind} for DelayedDataFrame inherits the lazyIndex's if
#' inputs are all DelayedDataFrame. Otherwise, return a new
#' DelayedDataFrame with NULL lazyIndexes.
#' @exportMethod cbind
#' @rdname DelayedDataFrame-method
#' @param ... One or more vector-like or matrix-like objects. These
#'     can be given as named arguments.
#' @param deparse.level See ‘?base::cbind’ for a description of this argument.
#' @aliases cbind,DelayedDataFrame-method

setMethod("cbind", "DelayedDataFrame", function(..., deparse.level=1)
{
    ## df <- callNextMethod()
    ## DelayedDataFrame(df)
    ## browser()
    DelayedDataFrame(..., check.names = FALSE)
})

#' bindROWS is the lower-level function for \code{rbind}.
#' @rdname DelayedDataFrame-method
#' @aliases bindROWS,DelayedDataFrame-method
setMethod(
    "bindROWS", "DelayedDataFrame",
    function(x, objects = list(), use.names = TRUE, ignore.mcols = FALSE, check = TRUE)
{
    ans <- callNextMethod()
    lazyIndex(ans) <- LazyIndex(vector("list", 1), rep(1L, ncol(x)))
    ans
})

###--------------------
## subsetting methods
###--------------------
#' @importFrom methods slot
.extractROWS_DelayedDataFrame <- function(x, i)
{
    i <- normalizeSingleBracketSubscript(
        i, x, exact = FALSE, allow.NAs = TRUE, as.NSBS = FALSE)
    rownames <- rownames(x)[i]
    if (!is.null(rownames))
        rownames <- make.unique(rownames)

    initialize(
        x, lazyIndex = lazyIndex(x)[i,], nrows = length(i), rownames = rownames
    )
}
#' @importFrom stats setNames
#' @exportMethod extractROWS
#' @aliases extractROWS,DelayedDataFrame-method
#' @rdname DelayedDataFrame-method
setMethod("extractROWS", "DelayedDataFrame", .extractROWS_DelayedDataFrame)

setReplaceMethod(
    "[", c("DelayedDataFrame", "ANY"),
    function(x, i, j, ..., value)
{
    xstub <- setNames(seq_along(x), names(x))
    if (missing(j)) {
        i <- normalizeSingleBracketSubscript(i, xstub)
        lazyIndex(x) <- .update_index(lazyIndex(x), i, NULL)
    } else {
        j <- normalizeSingleBracketSubscript(j, xstub)
        x@listData[j] <- lapply(j, function(j, x) x[[j]], x)
        lazyIndex(x) <- .update_index(lazyIndex(x), j, NULL)
    }
    callNextMethod()
})

#' @importFrom stats setNames
#' @importFrom methods callNextMethod
#' @exportMethod [
#' @aliases [,DelayedDataFrame-method
#' @rdname DelayedDataFrame-class
#' @param x input
#' @param i row subscript
#' @param j col subscript
#' @param drop if drop with reduced dimension, default is TRUE.
#' @param row.names rownames
#' @param check.names if check names.
#' @param ... other arguments to pass.

setMethod("[", c("DelayedDataFrame", "ANY", "ANY", "ANY"),
          function (x, i, j, ..., drop = TRUE) 
{
    if (!isTRUEorFALSE(drop)) 
        stop("'drop' must be TRUE or FALSE")
    if (length(list(...)) > 0L) 
        warning("parameters in '...' not supported")
    list_style_subsetting <- (nargs() - (!missing(drop))) < 3L
    if (list_style_subsetting || !missing(j)) {
        if (list_style_subsetting) {
            if (!missing(drop)) 
                warning("'drop' argument ignored by list-style subsetting")
            if (missing(i)) 
                return(x)
            j <- i
        }
        if (!is(j, "IntegerRanges")) {
            xstub <- setNames(seq_along(x), names(x))
            j <- normalizeSingleBracketSubscript(j, xstub)
        }
        x <- initialize(
            x, lazyIndex = lazyIndex(x)[j], listData = extractROWS(x@listData, j),
            elementMetadata = extractROWS(mcols(x), j)
        )
        if (anyDuplicated(names(x))) 
            names(x) <- make.unique(names(x))
        if (list_style_subsetting) 
            return(x)
    }
    if (!missing(i)) {
        x <- extractROWS(x, i)
    }
    if (missing(drop)) 
        drop <- ncol(x) == 1L
    if (drop) {
        if (ncol(x) == 1L) 
            return(x[[1L]])
        if (nrow(x) == 1L) 
            return(as(x, "list"))
    }
    x
})


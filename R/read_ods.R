.change_df_with_col_row_header <- function(x, col_header, row_header, .name_repair) {
    if((nrow(x) < 2 && col_header )|| (ncol(x) < 2 && row_header)) {
        warning("Cannot make column/row names if this would cause the dataframe to be empty.", call. = FALSE)
        return(x)
    }
    irow <- ifelse(col_header, 2, 1)
    jcol <- ifelse(row_header, 2, 1)

    g <- x[irow:nrow(x), jcol:ncol(x), drop=FALSE] # maintain as dataframe for single column


    rownames(g) <- if(row_header) x[seq(irow, nrow(x)), 1] else NULL # don't want character row headers given by 1:nrow(g)
    cols <- ncol(x)
    if (row_header) {
        cols <- cols - 1
    }
    col_n <- if(col_header) x[1, seq(jcol, ncol(x))] else c(rep("", cols))
    colnames(g) <- vctrs::vec_as_names(unlist(col_n), repair = .name_repair)
    return(g)
}

## Based on readxl, although the implementation is different.
## If max row is -1, read to end of row. 
## Row and column-numbers are 1-based
.standardise_limits <- function(range, skip) {
    if(is.null(range)) {
        skip <- check_nonnegative_integer(x = skip, argument = "skip")
        limits <- c(
            min_row = skip + 1,
            max_row = -1,
            min_col = 1,
            max_col = -1
        )
    } else {
        if(skip != 0) {
            warning("Range and non-zero value for skip given. Defaulting to range.", call. = FALSE)
        }
        tryCatch({
        limits <- cellranger::as.cell_limits(range)
        }, error = function(e) {
            stop("Invalid `range`")
        })
        limits <- c(
            min_row = limits[["ul"]][1],
            max_row = limits[["lr"]][1],
            min_col = limits[["ul"]][2],
            max_col = limits[["lr"]][2]
        )
    }
    return(limits)
}

.silent_type_convert <- function(x, verbose = TRUE, na = c("", "NA")) {
    if (verbose) {
        res <- readr::type_convert(df = x, na = na)
    } else {
        suppressMessages({
            res <- readr::type_convert(df = x, na = na)
        })
    }
    return(res)
}

.convert_strings_to_factors <- function(df) {
    i <- vapply(df, is.character, logical(1))
    df[i] <- lapply(df[i], as.factor)
    return(df)
}

.check_read_args <- function(path,
                        sheet = 1,
                        col_names = TRUE,
                        col_types = NULL,
                        na = "",
                        skip = 0,
                        formula_as_formula = FALSE,
                        range = NULL,
                        row_names = FALSE,
                        strings_as_factors = FALSE,
                        verbose = FALSE,
                        as_tibble = TRUE) {
    if (missing(path) || !is.character(path)) {
        stop("No file path was provided for the 'path' argument. Please provide a path to a file to import.", call. = FALSE)
    }
    if (!file.exists(path)) {
        stop("file does not exist", call. = FALSE)
    }
    if (!is.logical(col_names)) {
        stop("col_names must be of type `boolean`", call. = FALSE)
    }
    if (!is.logical(formula_as_formula)) {
        stop("formula_as_formula must be of type `boolean`", call. = FALSE)
    }
    if (!is.logical(row_names)) {
        stop("row_names must be of type `boolean`", call. = FALSE)
    }
    if (!is.logical(strings_as_factors)) {
        stop("strings_as_factors must be of type `boolean`", call. = FALSE)
    }
    if (!is.logical(verbose)) {
        stop("verbose must be of type `boolean`", call. = FALSE)
    }
    if (!is.logical(as_tibble)) {
        stop("as_tibble must be of type `boolean", call. = FALSE)
    }
    if (row_names && as_tibble) {
        stop("Tibbles do not support row names. To use row names, set as_tibble to false", call. = FALSE)
    }
}

.read_ods <- function(path,
                        sheet = 1,
                        col_names = TRUE,
                        col_types = NULL,
                        na = "",
                        skip = 0,
                        formula_as_formula = FALSE,
                        range = NULL,
                        row_names = FALSE,
                        strings_as_factors = FALSE,
                        verbose = FALSE,
                        as_tibble = TRUE,
                        .name_repair = "unique",
                        flat = FALSE) {
    .check_read_args(path,
        sheet,
        col_names,
        col_types,
        na,
        skip,
        formula_as_formula,
        range,
        row_names,
        strings_as_factors,
        verbose,
        as_tibble)
    # Get cell range info
    limits <- .standardise_limits(range, skip)
    # Get sheet number.
    if (flat) {
        sheets <- get_flat_sheet_names_(file = path, include_external_data = TRUE)
    } else {
        sheets <- get_sheet_names_(file = path, include_external_data = TRUE)
    }
    sheet_name <- cellranger::as.cell_limits(range)[["sheet"]]
    if(!is.null(range) && !is.na(sheet_name)) {
        if(sheet != 1) {
            warning("Sheet suggested in range and using sheet argument. Defaulting to range",
                call. = FALSE)
        }
        is_in_sheet_names <- stringi::stri_cmp(e1 = sheet_name, e2 = sheets) == 0
        if(any(is_in_sheet_names)) {
            sheet <- which(is_in_sheet_names)
        } else {
            stop(paste0("No sheet found with name '", sheet_name, "'", sep = ""),
                call. = FALSE)
        }
    } else {
        is_in_sheet_names <- stringi::stri_cmp(e1 = sheet, e2 = sheets) == 0
        if (!is.numeric(sheet) && any(is_in_sheet_names)) {
            sheet <- which(is_in_sheet_names)
        } else if (!is.numeric(sheet)) {
            stop(paste0("No sheet found with name '", sheet, "'", sep = ""), 
                call. = FALSE)
        }
        if (sheet > length(sheets)) {
            stop(paste0("File contains only ", length(sheets), " sheets. Sheet index out of range.",
                call. = FALSE))
        }
    }

    if(flat) {
        strings <- read_flat_ods_(file = path,
                                  start_row = limits["min_row"],
                                  stop_row = limits["max_row"],
                                  start_col = limits["min_col"],
                                  stop_col = limits["max_col"],
                                  sheet = sheet,
                                  formula_as_formula = formula_as_formula)
    } else {
        strings <- read_ods_(file = path,
                             start_row = limits["min_row"],
                             stop_row = limits["max_row"],
                             start_col = limits["min_col"],
                             stop_col = limits["max_col"],
                             sheet = sheet,
                             formula_as_formula = formula_as_formula)
    }
    if(strings[1] == 0 || strings[2] == 0) {
        warning("empty sheet, return empty data frame.", call. = FALSE)
        if(as_tibble) {
            return(tibble::tibble())
        } else {
            return(data.frame())
        }
    }
    res <- as.data.frame(
        matrix(
            strings[-1:-2],
            ncol = strtoi(strings[1]),
            byrow = TRUE),
        stringsAsFactors = FALSE)
    res <- .change_df_with_col_row_header(x = res, col_header = col_names, row_header = row_names, .name_repair = .name_repair)
    res <- data.frame(res)
    if (inherits(col_types, 'col_spec')) {
        res <- readr::type_convert(df = res, col_types = col_types, na = na)
    } else if (length(col_types) == 0 && is.null(col_types)) {
        res <- .silent_type_convert(x = res, verbose = verbose, na = na)
    } else if (length(col_types) == 1 && is.na(col_types[1])) {
        {} #Pass
    } else {
        stop("Unknown col_types. Can either be a class col_spec, NULL or NA.",
            call. = FALSE)
    }

    if (strings_as_factors) {
        res <- .convert_strings_to_factors(df = res)
    }

    if (as_tibble) {
        res <- tibble::as_tibble(x = res, .name_repair = .name_repair)
    }
    return(res)

}

#' Read Data From (F)ODS File
#'
#' read_ods is a function to read a single sheet from an (f)ods file and return a data frame. For flat ods files (.fods or .xml),
#' use (\code{read_fods}).
#'
#' @param path path to the (f)ods file.
#' @param sheet sheet to read. Either a string (the sheet name), or an integer sheet number. The default is 1.
#' @param col_names logical, indicating whether the file contains the names of the variables as its first line. Default is TRUE.
#' @param col_types Either NULL to guess from the spreadsheet or refer to [readr::type_convert()] to specify cols specification. NA will return a data frame with all columns being "characters".
#' @param na Character vector of strings to use for missing values. By default read_ods converts blank cells to missing data. It can also be set to
#' NULL, so that empty cells are treated as NA.
#' @param skip the number of lines of the data file to skip before beginning to read data. If this parameter is larger than the total number of lines in the ods file, an empty data frame is returned.
#' @param formula_as_formula logical, a switch to display formulas as formulas "SUM(A1:A3)" or as the resulting value "3"... or "8".. . Default is FALSE.
#' @param range selection of rectangle using Excel-like cell range, such as \code{range = "D12:F15"} or \code{range = "R1C12:R6C15"}. Cell range processing is handled by the \code{\link[=cellranger]{cellranger}} package.
#' @param row_names logical, indicating whether the file contains the names of the rows as its first column. Default is FALSE.
#' @param strings_as_factors logical, if character columns to be converted to factors. Default is FALSE.
#' @param verbose logical, if messages should be displayed. Default is FALSE.
#' @param as_tibble logical, if the output should be a tibble (as opposed to a data.frame). Default is TRUE.
#' @param .name_repair A string or function passed on as `.name_repair` to [tibble::as_tibble()]
#'  - `"minimal"`: No name repair
#'  - `"unique"` : Make sure names are unique and not empty
#'  - `"check_unique"`: Check names are unique, but do not repair
#'  - `"universal"` : Checks names are unique and valid R variables names in scope
#'  - A function to apply custom name repair.
#'  
#'  Default is `"unique"`.
#'  
#' @return A tibble (\code{tibble}) or data frame (\code{data.frame}) containing a representation of data in the (f)ods file.
#' @author Peter Brohan <peter.brohan+cran@@gmail.com>, Chung-hong Chan <chainsawtiney@@gmail.com>, Gerrit-Jan Schutten <phonixor@@gmail.com>
#' @examples
#' \dontrun{
#' # Read an ODS file
#' read_ods("starwars.ods")
#' # Read a specific sheet, e.g. the 2nd sheet
#' read_ods("starwars.ods", sheet = 2)
#' # Read a specific range, e.g. A1:C11
#' read_ods("starwars.ods", sheet = 2, range = "A1:C11")
#' # Read an FODS file
#' read_fods("starwars.fods")
#' # Read a specific sheet, e.g. the 2nd sheet
#' read_fods("starwars.fods", sheet = 2)
#' # Read a specific range, e.g. A1:C11
#' read_fods("starwars.fods", sheet = 2, range = "A1:C11")
#' }
#' @export
read_ods <- function(path,
                     sheet = 1,
                     col_names = TRUE,
                     col_types = NULL,
                     na = "",
                     skip = 0,
                     formula_as_formula = FALSE,
                     range = NULL,
                     row_names = FALSE,
                     strings_as_factors = FALSE,
                     verbose = FALSE,
                     as_tibble = TRUE,
                     .name_repair = "unique") {
    ## Should use match.call but there's a weird bug if one of the variable names is 'file'
    .read_ods(path = path,
        sheet = sheet,
        col_names = col_names,
        col_types = col_types,
        na = na,
        skip = skip,
        formula_as_formula = formula_as_formula,
        range = range,
        row_names = row_names,
        strings_as_factors = strings_as_factors,
        verbose = verbose,
        as_tibble = as_tibble,
        .name_repair = .name_repair,
        flat = FALSE)
}

#' @rdname read_ods
#' @export
read_fods <- function(path,
                        sheet = 1,
                        col_names = TRUE,
                        col_types = NULL,
                        na = "",
                        skip = 0,
                        formula_as_formula = FALSE,
                        range = NULL,
                        row_names = FALSE,
                        strings_as_factors = FALSE,
                        verbose = FALSE,
                        as_tibble = TRUE,
                        .name_repair = "unique") {
    ## Should use match.call but there's a weird bug if one of the variable names is 'file'
    .read_ods(path = path,
              sheet = sheet,
              col_names = col_names,
              col_types = col_types,
              na = na,
              skip = skip,
              formula_as_formula = formula_as_formula,
              range = range,
              row_names = row_names,
              strings_as_factors = strings_as_factors,
              verbose = verbose,
              as_tibble = as_tibble,
              .name_repair = .name_repair,
              flat = TRUE)
}

#' Get information in an (F)ODS File
#' 
#' `list_(f)ods_sheets` lists all sheets in an (f)ods file. 
#' 
#' @param path Path to the (f)ods file
#' @param include_external_data A boolean value to show or hide sheets containing archived linked data (default false)
#' @return For `list_(f)ods_sheets`, a character vector of sheet names; for `get_num_sheets_in_(f)ods`, the total number of sheets
#' @details `ods_sheets` will be removed in the next major version. It was kept for backward compatibility. Please use `list_ods_sheet`
#' instead. The default "include_external_data" for `ods_sheets` is TRUE to maintain compatibility with version 1 of readODS.
#' @author Peter Brohan <peter.brohan+cran@@gmail.com>, Chung-hong Chan <chainsawtiney@@gmail.com>, Gerrit-Jan Schutten <phonixor@@gmail.com>
#' @examples
#' \dontrun{
#' # Get the list of names of sheets
#' list_ods_sheets("starwars.ods")
#' list_fods_sheets("starwars.fods")
#' }
#' @seealso
#' use \code{\link{read_ods}} to read the data
#' @export
list_ods_sheets <- function(path, include_external_data = FALSE) {
    return(get_sheet_names_(file = path, include_external_data = include_external_data))
}

#' @rdname list_ods_sheets
#' @export
list_fods_sheets <- function(path, include_external_data = FALSE) {
    return(get_flat_sheet_names_(file = path, include_external_data = include_external_data))
}


#' @rdname list_ods_sheets
#' @export
ods_sheets <- function(path) {
    warning("ods_sheets will be deprecated in the next major version. Use `list_ods_sheets` instead.")
    list_ods_sheets(path, include_external_data = TRUE)
}

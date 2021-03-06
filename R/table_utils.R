#' Generates a 96 motif table based on input counts for plotting
#'
#' @param sample_df Input counts table
#' @return Returns a 96 motif summary table
table_96 <- function(sample_df) {
  motif <- names(sample_df)
  expanded <- rep(motif, sample_df)
  context <- substr(expanded, 5, 7)
  final_mut_type <- substr(expanded, 1, 3)
  final_mut_context <- context

  forward_change <- c("C>A", "C>G", "C>T", "T>A", "T>C", "T>G")

  ## Define all mutation types for 96 substitution scheme
  b1 <- rep(c("A", "C", "G", "T"), each = 24)
  b2 <- rep(rep(c("C", "T"), each = 12), 4)
  b3 <- rep(c("A", "C", "G", "T"), 24)
  mut_trinuc <- apply(cbind(b1, b2, b3), 1, paste, collapse = "")
  mut_type <- rep(rep(forward_change, each = 4), 4)

  mut_id <- apply(cbind(mut_type, mut_trinuc), 1, paste, collapse = "_")
  expanded <- rep(motif, sample_df)
  mutation <- factor(expanded, levels = mut_id)

  mut_summary <- data.frame(mutation, Type = final_mut_type,
                            Context = final_mut_context,
                            stringsAsFactors = FALSE)
  return(mut_summary)
}

#' Extract count tables list from a bagel object
#'
#' @param bagel bagel to extract count tables list from
#' @return List of count tables objects
#' @export
extract_count_tables <- function(bagel) {
  #Check that object is a bagel
  if (!methods::is(bagel, "bagel")) {
    stop(strwrap(prefix = " ", initial = "", "The input object is not a
    'bagel' object, please use 'create_bagel' to create one."))
  }

  counts_table <- bagel@count_tables
  return(counts_table)
}

.extract_count_table <- function(bagel, table_name) {
  #Check that at least one table exists
  if (length(bagel@count_tables) == 0) {
    stop(strwrap(prefix = " ", initial = "", "The counts table is either
    missing or malformed, please run create tables e.g. [build_standard_table]
    prior to this function."))
  }

  #Check that table exists within this bagel
  if (!table_name %in% names(bagel@count_tables)) {
    stop(paste0("'", table_name, "' does not exist. Current table names are: ",
                paste(names(bagel@count_tables), collapse = ", ")))
  }

  return(extract_count_tables(bagel)[[table_name]]@count_table)
}

subset_count_tables <- function(bay, samples) {
  tables <- bay@count_tables
  table_names <- names(tables)
  for (name in table_names) {
    sub_tab <- tables[[name]]
    sub_tab@count_table <- sub_tab@count_table[, which(colnames(
      sub_tab@count_table) %in% samples)]
    tables[[name]] <- sub_tab
  }
  return(tables)
}

.create_count_table <- function(bay, name, count_table, features = NULL,
                               type = NULL, annotation = NULL,
                               color_variable = NULL, color_mapping = NULL,
                               description = "",
                               return_table = FALSE, overwrite = FALSE) {

  # Check that table name is unique compared to existing tables
  if (name %in% names(bay@count_tables) & !overwrite) {
    stop(paste("Table names must be unique. Current table names are: ",
               paste(names(bay@count_tables), collapse = ", "), sep = ""))
  }

  # Error checking of variables
  if (!inherits(count_table, "array")) {
    stop("The count table must be a matrix or array.")
  }
  if(!is.null(features) & is.null(type)) {
    stop("'type' must be supplied when including 'features.'")
  }
  if (!is.null(type)) {
    if(length(type) != nrow(features)) {
      stop("'type' must be the same length as the number of rows in 'features'")
    }
    type.rle = S4Vectors::Rle(type)
  } else {
    type.rle = NULL
  }
  if(!is.null(color_mapping)) {
    if(is.null(annotation)) {
      stop("In order to set 'color_mapping', the 'annotation' data ",
           "frame must be supplied.")
    }
    # checks for color_variable
  }
  if(!is.null(color_mapping) & !is.null(color_variable) &
     !is.null(annotation)) {
    no_match = setdiff(names(color_mapping), annotation[,color_variable])
    if(length(no_match) > 0) {
      #warning()
    }
  }
  # Check for color_variable in column names of annotation

  tab <- new("count_table", name = name, count_table = count_table,
             annotation = annotation, features = features,
             type = type.rle, color_variable = color_variable,
             color_mapping = color_mapping, description = description)

  if (isTRUE(return_table)) {
    return(tab)
  } else {
    tab <- list(tab)
    names(tab) <- name
    #bay@count_tables <- c(bay@count_tables, tab)
    .table_exists_warning(bay, name, overwrite)
    eval.parent(substitute(bay@count_tables[[name]] <- tab))
    #bay@count_tables[[name]] <- tab
    #return(bay)
  }
}

#' Builds a custom table from specified user variants
#'
#' @param bay Input samples
#' @param variant_annotation User column to use for building table
#' @param name Table name to refer to (must be unique)
#' @param description Optional description of the table content
#' @param data_factor Full set of table values, in case some are missing from
#' the data. If NA, a superset of all available unique data values will be used
#' @param annotation_df A data.frame of annotations to use for plotting
#' @param features A data.frame of the input data from which the count table
#' will be built
#' @param type The type of data/mutation in each feature as an Rle object
#' @param color_variable The name of the column of annotation_df used for the
#' coloring in plots
#' @param color_mapping The mapping from the values in the selected
#' color_variable column to color values for plotting
#' @param return_instead Instead of adding to bagel object, return the created
#' table
#' @param overwrite Overwrite existing count table
#' @examples
#' bay <- readRDS(system.file("testdata", "bagel.rds", package = "BAGEL"))
#' annotate_transcript_strand(bay, "19", build_table = FALSE)
#' build_custom_table(bay, "Transcript_Strand", "Transcript_Strand",
#' data_factor = factor(c("T", "U")))
#' @export
build_custom_table <- function(bay, variant_annotation, name,
                                 description = "", data_factor = NA,
                               annotation_df = NULL, features = NULL,
                               type = NULL, color_variable = NULL,
                               color_mapping = NULL, return_instead = FALSE,
                               overwrite = FALSE) {
  tab <- bay@count_tables
  variants <- bay@variants
  .table_exists_warning(bay = bay, table_name = name, overwrite = overwrite)

  #Check that variant column exists
  if (variant_annotation %in% colnames(variants)) {
    column_data <- variants[[variant_annotation]]
    sample_names <- unique(variants$sample)
    num_samples <- length(sample_names)
    default_factor <- levels(factor(column_data))
    variant_tables <- vector("list", length = num_samples)
    for (i in seq_len(num_samples)) {
      sample_index <- which(variants$sample == sample_names[i])
      if (!all(is.na(data_factor))) {
        variant_tables[[i]] <- table(factor(column_data[sample_index],
                                            levels = data_factor))
      } else {
        variant_tables[[i]] <- table(factor(column_data[sample_index],
                                            levels = default_factor))
      }
    }
    count_table <- do.call(cbind, variant_tables)
    colnames(count_table) <- sample_names
  } else {
    stop(paste("That variant annotation does not exist,",
               " existing annotations are: ", paste(colnames(variants),
                                                    collapse = ", "), sep = ""))
  }

  motif <- rownames(count_table)
  if (!hasArg(type)) {
    type <- rep(NA, sum(count_table))
  }
  if (!hasArg(features)) {
    features <- data.frame(mutation = rep(rownames(count_table),
                                          rowSums(count_table)))
  }
  if (!hasArg(annotation_df)) {
    annotation_df <- data.frame(motif = motif)
  }
  if (!hasArg(color_variable)) {
    color_variable <- "motif"
  }
  if (!hasArg(color_mapping)) {
    color_mapping <- .gg_color_hue(length(motif))
    names(color_mapping) <- annotation_df[, color_variable]
  }

  built_table <- .create_count_table(bay = bay,
                      name = name,
                      count_table = count_table,
                      features = features,
                      type = type,
                      annotation = annotation_df,
                      color_variable = color_variable,
                      color_mapping = color_mapping,
                      return_table = TRUE,
                      overwrite = overwrite,
                      description = description)
  if (return_instead) {
    return(built_table)
  } else {
    eval.parent(substitute(bay@count_tables[[name]] <- built_table))
  }
}

combine_count_tables <- function(bay, to_comb, name, description = NA) {
  tab <- bay@count_tables

  #Check that table names are unique
  if (name %in% names(tab)) {
    stop(paste("Table names must be unique. Current table names are: ",
               paste(names(tab), collapse = ", "), sep = ""))
  }

  if (all(to_comb %in% tab@table_name)) {
    combo_table <- NULL
    for (i in seq_len(to_comb)) {
      combo_table <- rbind(combo_table, tab@table_list[[to_comb[i]]])
    }
    tab@table_list[[name]] <- combo_table
  } else {
    stop(paste("User specified table: ",
               setdiff(to_comb, tab@table_name), " does not exist, please ",
               "create prior to creating compound table. ",
               "Current table names are: ", paste(tab@table_name,
                                                  collapse = ", "), sep = ""))
  }
  tab@table_name[[name]] <- name
  tab@description[[name]] <- description
  eval.parent(substitute(bay@count_tables <- tab))
}

drop_count_table <- function(bay, table_name) {
  tab <- bay@count_tables
  if (!table_name %in% names(tab)) {
    stop(paste(table_name, " does not exist. Current table names are: ",
               names(tab), sep = ""))
  }
  tab[[table_name]] <- NULL
  eval.parent(substitute(bay@count_tables <- tab))
}

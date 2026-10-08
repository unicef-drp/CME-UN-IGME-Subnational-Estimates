source(file.path("Rcode", "_supporting_scripts", "getBB8.R"))

model_data <- data.frame(
  region = c("admin2_1", NA, "", "admin2_99"),
  value = seq_len(4),
  stringsAsFactors = FALSE
)

adjacency <- diag(2)
rownames(adjacency) <- colnames(adjacency) <- c("admin2_1", "admin2_2")

filtered <- filter_bb8_admin2_rows(model_data, adjacency)
stopifnot(identical(filtered$data$value, 1L))
stopifnot(identical(filtered$dropped, 3L))

all_invalid <- model_data[-1, , drop = FALSE]
error_message <- tryCatch(
  {
    filter_bb8_admin2_rows(all_invalid, adjacency)
    NA_character_
  },
  error = function(err) conditionMessage(err)
)

stopifnot(grepl("No rows have a valid Admin2 region", error_message, fixed = TRUE))

cat("BB8 filters records without a mapped Admin2 region.\n")

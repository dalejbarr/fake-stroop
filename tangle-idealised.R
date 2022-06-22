options(crayon.enabled=FALSE)
library("readr")

all_lines <- read_lines("analysis-realistic.R")

hdr_end <- max(grep("^library", all_lines))

tail_begin <- grep("^sub_effects <-", all_lines)

stopifnot(length(tail_begin) == 1L)

write_lines(
  c(all_lines[seq_len(hdr_end)], "",
    "sub_means_wide <- read_csv(\"subject-means.csv\", col_types = \"cii\")", "",
    all_lines[(tail_begin - 1L):length(all_lines)]),
  file = "analysis-idealised.R")

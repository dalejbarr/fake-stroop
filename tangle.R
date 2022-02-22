library("tidyverse")

## tangle into scripts for easy processing later
knitr::purl("analyse-stroop.Rmd",
            output = tf <- tempfile(fileext = ".R"))

get_chunk <- function(range, code_lines) {
  code_lines[range[1]:range[2]]
}

code_lines <- read_lines(tf)

.delimiters <- grep("^##\\s----", code_lines)

.ranges <- rbind(.delimiters + 1,
                 c(.delimiters[-1] - 1, length(code_lines)))

colnames(.ranges) <- sub("^##\\s----([A-Za-z-]+[A-Za-z]+)[,-].*-+$", "\\1",
    code_lines[.delimiters])

.idealised_chunks <- c("idealised-setup", "idealised")
.realistic_chunks <- c("load-tidyverse", "import", "eng-lang-recode",
                       "transcript-recode", "trials", "combine",
                       "sub-means-wide", "idealised")

.code_ideal <- apply(.ranges[, .idealised_chunks], 2, get_chunk, code_lines)

write_lines(unlist(.code_ideal, use.names = FALSE),
            file = "analysis-idealised.R")

.code_real <- apply(.ranges[, .realistic_chunks], 2, get_chunk, code_lines)

write_lines(unlist(.code_real, use.names = FALSE),
            file = "analysis-realistic.R")

file.remove(tf)

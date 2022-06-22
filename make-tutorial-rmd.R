rmd_lines <- readr::read_lines("analyse-stroop-master.Rmd")

chunk_opts <- grep("^knitr::opts_chunk", rmd_lines)
rmd_lines[chunk_opts] <- "knitr::opts_chunk$set(echo = TRUE, results=FALSE)"

cwd <- getwd()

rmd2 <- c(rmd_lines[1:chunk_opts],
          paste0("knitr::opts_knit$set(root.dir = \"", cwd, "\")"),
          rmd_lines[(chunk_opts + 1L):length(rmd_lines)])

knitr::knit(text = rmd2, output = tf <- tempfile(fileext = ".md"),
            quiet = TRUE)

all_lines <- readr::read_lines(tf)
file.remove(tf)

html_comments <- grep("^\\s*<!--.*-->\\s*$", all_lines)

all_lines2 <- all_lines[-(html_comments)]
rm(all_lines)

## get rid of extra blank lines
blanks <- grep("^\\s*$", all_lines2)
vv <- diff(blanks) == 1L

streaks <- rle(vv)
csum1 <- cumsum(streaks$lengths)
sstart <- c(1L, csum1[-length(csum1)] + 1)
mx <- rbind(start = blanks[sstart],
            end = blanks[sstart + streaks$lengths - 1L])

nv <- apply(mx[, streaks$values], 2, function(.x) {seq(.x[1], .x[2], by = 1L)}) |>
  unlist()

all_lines3 <- all_lines2[-nv]
rm(all_lines2)

all_lines_rhead <- gsub("^```r", "```{r}", all_lines3)

## todo: add in the source data
grep("^#*\\s*[Ss]ource\\s*[Dd]ata\\s*.$", all_lines_rhead)

src_data <-grep("^#+\\s+[Ss]ource [Dd]ata", all_lines_rhead)

## add in demographics, transcript, sample trial data
demo_tbl <- grep("^#+\\s+`demographics.csv`\\s*$", all_lines_rhead)[1] + 3L

trans_tbl <- grep("^#+\\s+`transcript.csv`\\s*$", all_lines_rhead)[1] + 3L

trial_tbl <- grep("^#+\\s+[Tt]rial [Dd]ata\\s*$", all_lines_rhead)[1] + 3L

load("analysis.RData", ev <- new.env())

tfile <- ev[[".targ_file"]]

all_lines_final <- c(all_lines_rhead[1:src_data[1]],
  "", "```{r, echo=FALSE}",
  "readr::read_csv(\"subject-means.csv\", col_types = \"cii\")",
  "```", "",
  all_lines_rhead[(src_data[1]+1L):demo_tbl],
  "```{r, echo=FALSE}",
  "read_csv(\"sample/demographics.csv\", col_types = \"iic\")",
  "```", "",
  all_lines_rhead[(demo_tbl+1L):trans_tbl],
  "```{r, echo=FALSE}",
  "read_csv(\"sample/transcript.csv\", col_types = \"iic\")",
  "```", "",
  all_lines_rhead[(trans_tbl+1L):trial_tbl],
  "```{r, echo=FALSE}",
  paste0("read_csv(\"sample/", tfile, "\", col_types = \"iicc\")"),
  "```", "",
  all_lines_rhead[(trial_tbl+1L):length(all_lines_rhead)])

write_lines(all_lines_final, file = "analyse-stroop-tutorial.Rmd")

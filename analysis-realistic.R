library("tidyverse")
library("lsr") # for cohensD

## the data in the subdirectory 'sample' was created using the commands:
##
## source("simulate-stroop-data.R")
## set.seed(1001001)
## save_stroop(make_stroop(40), "sample", TRUE)
raw_data_subdir <- "sample"
stroop_colours <- c("blue", "brown", "green", "purple", "red")


## Import demographic data. Easy.
demo_raw <- read_csv(file.path(raw_data_subdir, "demographics.csv"),
                     col_types = "iic")

## Import the trial data.
## The regular expression "^S[0-9]*\\.csv$" is used to match filenames.
files_to_read <- dir(raw_data_subdir, "^S[0-9]*\\.csv$", full.names = TRUE)

## We can import multiple files at once, because `read_csv()` is vectorized.
trials_raw <- read_csv(files_to_read, id = "filename",
                       col_types = "iicc") %>%
  ## parse filename to extract subject identifier (integer)
  mutate(id = sub(".*S([0-9]*)\\.csv$", "\\1", filename) %>%
           as.integer()) %>%
  select(-filename) %>%
  select(id, everything()) # re-order columns

## Import transcript data
transcript_raw <- read_csv(file.path(raw_data_subdir, "transcript.csv"),
                           col_types = "iic")


demo <- demo_raw %>%
  mutate(age = if_else(between(age, 16, 100), age, NA_integer_),
         eng_lang = recode(tolower(eng_lang),
                           "nativ" = "native"))

## check whether there aren't any additional typos we've missed
eng_variants <- demo %>%
  filter(!is.na(eng_lang)) %>%
  distinct(eng_lang) %>%
  pull(eng_lang)

## stop processing if there are unhandled variants
stopifnot(setequal(eng_variants, c("native", "nonnative")))


transcript <- transcript_raw %>%
  mutate(response = recode(response,
                           "bleu" = "blue",
                           "bule" = "blue",
                           "borwn" = "brown",
                           "bronw" = "brown",
                           "brwon" = "brown",
                           "geren" = "green",
                           "grene" = "green",
                           "pruple" = "purple",
                           "puprle" = "purple",
                           "purpel" = "purple",
                           "purlpe" = "purple",
                           "rde" = "red"))
                           
colour_variants <- transcript %>%
  distinct(response) %>%
  pull()

stopifnot(setequal(colour_variants, stroop_colours))


trials_cond <- trials_raw %>%
  filter(event == "DISPLAY_ON") %>%
  select(-timestamp, -event) %>%
  separate(data, c("stimword", "inkcolour"), "-") %>%
  mutate(inkcolour = sub("\\.png$", "", inkcolour), # get rid of .png
         condition = if_else(tolower(stimword) == inkcolour,
                             "congruent", "incongruent"))

trials_acc <- left_join(trials_cond, transcript,
                        c("id", "trial")) %>%
  mutate(is_accurate = (response == inkcolour))

trials_rt <- trials_raw %>%
  select(-data) %>%
  pivot_wider(names_from = event, values_from = timestamp) %>%
  mutate(rt = VOICE_KEY - DISPLAY_ON) %>%
  select(-DISPLAY_ON, -VOICE_KEY)

trials <- inner_join(trials_acc, trials_rt,
                         c("id", "trial")) %>%
  semi_join(demo %>% filter(!is.na(eng_lang)), "id")

n_trials_wrong <- trials %>% filter(!is_accurate) %>% nrow()
n_trials_NA <- trials %>% filter(is_accurate, is.na(rt)) %>% nrow()


sub_means <- inner_join(demo, trials, "id") %>%
  filter(is_accurate) %>%
  group_by(id, eng_lang, condition) %>%
  summarise(mean_rt = round(mean(rt, na.rm = TRUE)) %>%
              as.integer(),
            .groups = "drop") 


sub_means_wide <- sub_means %>%
  pivot_wider(names_from = condition,
              values_from = mean_rt)


## calculate the stroop effect for each participant
sub_effects <- sub_means_wide %>%
  mutate(effect = incongruent - congruent)

## calculate the overall effects
overall_stroop <- sub_effects %>%
  pull(effect)

overall_sd <- sd(overall_stroop)

## one-sample t-test
one_samp_t <- t.test(overall_stroop)

## effect size
overall_d <- cohensD(overall_stroop) # from lsr package

## independent-samples t-test
t_stats <- t.test(effect ~ eng_lang, sub_effects,
                  var.equal = TRUE)

## descriptives not provided in t-test output
group_stats <- sub_effects %>%
  group_by(eng_lang) %>%
  summarise(sd_effect = sd(effect), N = n())

## effect size
group_d <- cohensD(effect ~ eng_lang, sub_effects)



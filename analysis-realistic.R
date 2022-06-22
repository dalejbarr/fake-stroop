## load relevant packages
library("tidyverse") # for data wrangling
library("lsr")       # for cohensD

## Import demographic data.
demo_raw <- read_csv("sample/demographics.csv", 
                     col_types = "iic")

## Import transcript data
transcript_raw <- read_csv("sample/transcript.csv",
                           col_types = "iic")

## The regular expression "^S[0-9]*\\.csv$" is used to match filenames.
files_to_read <- list.files(path = "sample", 
                            pattern = "^S[0-9]{2}\\.csv$", 
                            full.names = TRUE)

## We can import multiple files at once, because `read_csv()` is vectorized.
trials_raw <- read_csv(files_to_read, 
                       id = "filename", # adds an id column with the filename
                       col_types = "iicc") %>%
  ## parse filename to extract subject identifier (integer)
  mutate(id = gsub("[^0-9]", "", filename) %>% as.integer()) %>%
  select(-filename) %>%    # remove the filename column
  select(id, everything()) # re-order columns

## 'age' and 'eng_lang' were manually typed in, so check & repair problems
demo <- demo_raw %>%
  mutate(age = ifelse(between(age, 16, 100), age, NA),
         eng_lang = recode(tolower(eng_lang),
                           "nativ" = "native"))

## check whether there aren't any additional typos we've missed
eng_variants <- demo %>%
  filter(!is.na(eng_lang)) %>%
  distinct(eng_lang) %>%
  pull(eng_lang)

## stop processing if there are unhandled variants
language_values <- c("native", "nonnative")
stopifnot(setequal(eng_variants, language_values))

## Deal with potential typos in the transcript data
colour_responses <- transcript_raw %>%
  count(response) %>%
  arrange(n)

## can copy and paste into 'recode()' statement
dput(colour_responses$response)

## fix typos
transcript <- transcript_raw %>%
  mutate(response = recode(response,
                           "puprle" = "purple", 
                           "purlpe" = "purple", 
                           "brwon"  = "brown", 
                           "pruple" = "purple", 
                           "purpel" = "purple", 
                           "bronw"  = "brown", 
                           "bleu"   = "blue", 
                           "borwn"  = "brown", 
                           "geren"  = "green", 
                           "bule"   = "blue", 
                           "grene"  = "green", 
                           "rde"    = "red"))

# check if there are any unhandled variants
stroop_colours <- c("blue", "brown", "green", "purple", "red")

colour_variants <- transcript %>%
  distinct(response) %>%
  pull()

stopifnot(setequal(colour_variants, stroop_colours))

trials_rt <- trials_raw %>%
  select(-data) %>%
  pivot_wider(names_from = event, 
              values_from = timestamp) %>%
  mutate(rt = VOICE_KEY - DISPLAY_ON)

## derive trial condition
trials_cond <- trials_raw %>%
  filter(event == "DISPLAY_ON") %>%
  select(id, trial, data) %>%
  separate(data, 
           into = c("stimword", "inkcolour"), 
           sep = "-",
           remove = FALSE) %>%
  mutate(inkcolour = sub("\\.png$", "", inkcolour), # get rid of .png
         condition = if_else(tolower(stimword) == inkcolour,
                             "congruent", "incongruent"))

## calculate accuracy
trials_acc <- left_join(trials_cond, transcript,
                        c("id", "trial")) %>%
  mutate(is_accurate = (response == inkcolour))

## combine accuracy and RT data
trials <- inner_join(trials_acc, trials_rt,
                     c("id", "trial")) %>%
  select(-data, -DISPLAY_ON, -VOICE_KEY)

## note that we round off the means so they match the idealised data
sub_means <- inner_join(demo, trials, "id") %>%
  filter(is_accurate, !is.na(eng_lang)) %>%
  group_by(id, eng_lang, condition) %>%
  summarise(mean_rt = round(mean(rt, na.rm = TRUE)),
            .groups = "drop")

## pivot to wide to allow calculation of subject effects
sub_means_wide <- sub_means %>%
  pivot_wider(names_from = condition,
              values_from = mean_rt)



## calculate the stroop effect for each participant
sub_effects <- sub_means_wide %>%
  mutate(effect = incongruent - congruent)

# get just the column of interest
overall_stroop <- sub_effects %>%
  pull(effect)

## standard deviation
overall_sd <- sd(overall_stroop)

## one-sample t-test
one_samp_t <- t.test(overall_stroop)

## effect size
overall_d <- cohensD(overall_stroop) # from lsr package

## descriptives
group_stats <- sub_effects %>%
  group_by(eng_lang) %>%
  summarise(mean_effect = mean(effect),
            sd_effect = sd(effect), 
            N = n())

## independent-samples t-test
two_samp_t <- t.test(formula = effect ~ eng_lang, 
                  data = sub_effects,
                  var.equal = TRUE)

## effect size
group_d <- cohensD(effect ~ eng_lang, 
                   data = sub_effects)

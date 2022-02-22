library("tidyverse")
library("lsr") # for cohensD

sub_means_wide <- read_csv("subject-means.csv", col_types = "cii")


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



## load relevant packages
library("tidyverse") # for data wrangling
library("lsr")       # for cohensD

sub_means_wide <- read_csv("subject-means.csv", col_types = "cii")

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

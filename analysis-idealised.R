# load relevant packages
library("tidyverse") # for data wrangling
library("lsr")       # for cohensD
library("glue")      # for combining variables with text


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
two_samp_t <- t.test(formula = effect ~ eng_lang, 
                     data = sub_effects,
                     var.equal = TRUE)

## descriptives not provided in t-test output
group_stats <- sub_effects %>%
  group_by(eng_lang) %>%
  summarise(mean_effect = mean(effect),
            sd_effect = sd(effect), N = n())

## effect size
group_d <- cohensD(effect ~ eng_lang, 
                   data = sub_effects)



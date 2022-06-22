## tangle into scripts for easy processing later
knitr::purl("analyse-stroop-master.Rmd",
            output = "analysis-realistic.R",
            documentation = 0L)

datafiles := $(wildcard sample/*.csv)

default : analyse-stroop-tutorial.html analyse-stroop-python.html

sample :
	Rscript -e "source('simulate-stroop-data.R'); set.seed(1001001); save_stroop(make_stroop(40), 'sample', TRUE)"

analyse-stroop-tutorial.html : analyse-stroop-tutorial.Rmd
	Rscript -e "rmarkdown::render('analyse-stroop-tutorial.Rmd')"

analyse-stroop-tutorial.Rmd : $(datafiles) analyse-stroop-master.Rmd analysis-idealised.R make-tutorial-rmd.R
	Rscript make-tutorial-rmd.R

analyse-stroop-python.html : $(datafiles) analyse-stroop-python.qmd
	quarto render analyse-stroop-python.qmd

# analyse-stroop.ipynb : analyse-stroop-python.qmd
# 	quarto convert analyse-stroop-python.qmd

analysis-idealised.R : analysis-realistic.R tangle-idealised.R
	Rscript tangle-idealised.R

analysis-realistic.R : analyse-stroop-master.Rmd tangle-realistic.R
	Rscript tangle-realistic.R

clean :
	rm -f analyse-stroop-tutorial.Rmd analyse-stroop-tutorial.html analyse-stroop-python.html analysis-realistic.R analysis-idealised.R

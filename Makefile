default : analyse-stroop.html analyse-stroop-python.html

sample :
	Rscript -e "source('simulate-stroop-data.R'); set.seed(1001001); save_stroop(make_stroop(40), 'sample', TRUE)"

analyse-stroop.html : sample/demographics.csv analyse-stroop.Rmd analysis-idealised.R
	Rscript -e "rmarkdown::render('analyse-stroop.Rmd')"

analyse-stroop-python.html : sample/demographics.csv analyse-stroop-python.qmd
	quarto render analyse-stroop-python.qmd

# analyse-stroop.ipynb : analyse-stroop-python.qmd
# 	quarto convert analyse-stroop-python.qmd

analysis-idealised.R : analyse-stroop.Rmd tangle.R
	Rscript tangle.R

clean :
	rm analyse-stroop.html analyse-stroop-python.html

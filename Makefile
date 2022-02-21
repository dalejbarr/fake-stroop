default : analyse-stroop.html

sample :
	Rscript -e "source('simulate-stroop-data.R'); set.seed(1001001); save_stroop(make_stroop(40), 'sample', TRUE)"

analyse-stroop.html : sample/demographics.csv analyse-stroop.Rmd
	Rscript -e "rmarkdown::render('analyse-stroop.Rmd')"

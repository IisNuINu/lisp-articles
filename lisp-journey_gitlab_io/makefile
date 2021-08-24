
HTML = clos-tutorial.html \
       common-lisp-macros-by-example-tutorial.html \
       compile-time-type-checking-in-common-lisp.html \
       debugging-in-common-lisp.html \
       models-and-databases-mito-sxql.html

%.html : %.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html
	po2txt -i $*.po -o $*.html


all : $(HTML)
	echo ALL!



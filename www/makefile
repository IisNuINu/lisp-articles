
HTML = ElephantUserManual.html  Hunchentoot.html  lispweb2.html  \
       lispweb.html


%.html : %.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html
	po2txt -i $*.po -o $*.html

process.md : process.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html
	po2txt -i $< -o $@


all : $(HTML)
	echo ALL!



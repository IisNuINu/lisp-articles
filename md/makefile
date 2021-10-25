

MD =  process.md


%.html : %.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html
	po2txt -i $*.po -o $*.html

%.md : %.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html
	po2txt -i $*.po -o $*.md


#process.md : process.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html#
#	po2txt -i $< -o $@


all : $(MD)
	echo ALL!



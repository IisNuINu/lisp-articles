
HTML = Revisiting_Prechelts_paper_and_follow-ups_comparing_Java_Lisp,_CorC++_and_scripting_languages.html \
       a-gentle-introduction-to-compile-time-computing-part-1.html \
       a-gentle-introduction-to-compile-time-computing-part-2.html \
       Compile_Time_Debugging.html \
       UnderstandingPowerLISP.html \
       Exceptional-Situations-1990.html Condition-Handling-2001.html \
       introduction-to-asdf.html SimpleCLX.html \
       package-management-in-common-lisp-the-clim-way.html \
       continuations-in-common-lisp.html \
       2018-03-28-one-year-common-lisp-developer-part-2-the-bad-m.html \
       2018-03-28-one-year-common-lisp-developer-part-1-the-good-m.html \
       Static_type_checking_in_the_programmable_programming_language.html \
       a-gentle-introduction-to-compile-time-computing-part-3-scientific-units.html



%.html : %.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html
	po2txt -i $*.po -o $*.html

process.md : process.po
#	po2txt -i $*.po | sed -f remove_end.sed >$*.html
	po2txt -i $< -o $@


all : $(HTML)
	echo ALL!



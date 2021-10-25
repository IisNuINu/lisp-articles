
HTML = Revisiting_Prechelts_paper_and_follow-ups_comparing_Java_Lisp,_CorC++_and_scripting_languages.html \
       a-gentle-introduction-to-compile-time-computing-part-1.html \
       a-gentle-introduction-to-compile-time-computing-part-2.html \
       Compile_Time_Debugging.html \
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



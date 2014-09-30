makepub
=======

__makepub__ is a bash script that intends to convert a markdown file in a fully functionnal __epub__ file.

Features
--------

+ __Simple__ as possible, requirering as little user interaction as possible
+ Easily __customisable__; for example, the script actually converts `<hr>` tags to a simple unicode symbol of your choice, with the style of your choice
+ Can handle __different languages__ (currently en and fr) and their grammatical rules.
+ Provide a clean file which should be __compatible__ with the majority of e-readers

Requirements
------------

+ Bash
+ Perl (for markdown convertion)
+ basename / dirname (to find the paths)
+ sed (for character replacement)
+ csplit (to split chapters)
+ recode (for html entities conversion)

Shortcomings
------------

+ Not yet finished !
+ Crapy english translations
+ I'm still a Bash noob, so I may make mistakes. Feel free to edit.

__makepub__ is a bash script that intends to convert a markdown file in a fully functionnal __epub__ file.

Features
========

+ __Simple__ as possible, requirering as little user interaction as possible
+ Easily __customisable__; for example, the script actually converts `<hr>` tags to a simple unicode symbol of your choice, with the style of your choice
+ Can handle __different languages__ (currently _en_ and _fr_) and their grammatical rules.
+ Provide a clean file which should be __compatible__ with the majority of e-readers

Requirements
============

Software
--------

+ __Bash__
+ __Perl__ (for markdown convertion)
+ __basename__ / __dirname__ (to find the paths)
+ __sed__ (for character replacement)
+ __csplit__ (to split chapters)
+ __recode__ (for html entities conversion)

Files
-----

+ The file to be converted should use a markdown extension (optionnal).
+ Several files can be added to complete the book. All these files should be located on the same folder than the file to be converted, and use the same extension (and obviously be redacted in markdown).
    + _description_ file will be used to create a title page.
    + _contact_ file will be used to create contact/author bio.
    + _serie_ file will be used to create serie information page.
+ The main file is splitted at each `<h1>`, so your titles structure should take that into account (though this might be easily customizable in the script.

Shortcomings
============

+ Not yet finished !
+ Crapy english translations
+ I'm still a Bash noob, so I may make mistakes. Feel free to edit.

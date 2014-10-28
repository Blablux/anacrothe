#! /bin/bash

# automatic epub generation
# needs unix programs :
# - basename / dirname (to find the paths) (these programs are often pre-installed)
# - sed (to make character replacement) (this program is often pre-installed)
# - csplit (to split chapters) (this program is often pre-installed)
# - recode (for html entities conversion)
# - Perl (for markdown conversion)

function senderror()
{
 echo "$1" ;
 rm -r "$scriptpath/temp" ;
 exit 1 ;
}

function convertpage()
{
 sed -f "lang/sed_$lang.txt" "$filepath/$1.$ext" > "$scriptpath/temp/$1.tmp"
 sed -i ':a;N;$!ba;s/\n/  \n/g' "$scriptpath/temp/$1.tmp"
 sed -i ':a;N;$!ba;s/  \n  \n/\n\n/g' "$scriptpath/temp/$1.tmp"
 recode -dt u8..html "$scriptpath/temp/$1.tmp"
 perl "$scriptpath/markdown.pl" --html4tags "$scriptpath/temp/$1.tmp" > "$scriptpath/temp/$1.html"
}

function makexhtml()
{
 cat "$scriptpath/temp/header.txt" > "$filepath/review/OEBPS/Text/$2.xhtml"
 cat $1 >> "$filepath/review/OEBPS/Text/$2.xhtml"
 echo "</body></html>" >> "$filepath/review/OEBPS/Text/$2.xhtml"
}

function makenavpoint()
{
 echo -e "    <navPoint id="navPoint-$1" playOrder="$1">" >> "$filepath/review/OEBPS/toc.ncx"
 echo -e "      <navLabel>\n        <text>$2</text>\n      </navLabel>" >> "$filepath/review/OEBPS/toc.ncx"
 echo -e "     <content src="Text/$3.xhtml"/>\n    </navPoint>" >> "$filepath/review/OEBPS/toc.ncx"
}

scriptpath=`dirname $0`
# check if file exist
if [ ! -z $1 ] ;
then
  filepath=`dirname $1`
  filename=$(basename "$1")
  ext="${filename##*.}"
  filename="${filename%.*}"
  workingname="$scriptpath"/temp/"$filename"
  if [ ! -r $filepath/$filename.$ext ] ;
  then
    senderror "$filename.$ext can't be read!"
  fi
else
  senderror "You must supply the file to convert"
fi
mkdir "$scriptpath/temp"
mkdir "$filepath/review"
mkdir "$filepath/review/META-INF"
mkdir "$filepath/review/OEBPS"
mkdir "$filepath/review/OEBPS/Style"
mkdir "$filepath/review/OEBPS/Text"
cp "$scriptpath/data/mimetype" "$filepath/review/"
cp "$scriptpath/data/container.xml" "$filepath/review/META-INF/"
cp "$scriptpath/data/page-template.xpgt" "$filepath/review/OEBPS/Style/"
cp "$scriptpath/data/stylesheet.css" "$filepath/review/OEBPS/Style/"

# check if file is text and markdown
if ! file --mime-type "$1" | grep -q text/plain$; then
  echo "WARNING :$filename.$ext does not look like plain text"
  echo -n "Do you want to continue [y/n] ? " ; read textfile
  if [[ "$textfile" != [yY] ]] ; then
    exit 1
  elif [[ "$ext" != md && "$ext" != markdown && "$ext" != mdown && "$ext" != mkdn && "$ext" != mkd && "$ext" != mdwn && "$ext" != mdtxt && "$ext" != mdtext] ]] ;
  then
    echo "File doesn't use have a markdown extension."
    echo -n "Do you wish to continue? [y/n] ?" ; read markdown
    if [[ $markdown != [yY] ]] ;
    then
      exit 1
    fi
  fi
fi

# get metadata
echo "Please provide the metadata"
echo -n "Author: " ; read author
echo -n "Title: " ; read title
echo -n "Publisher: " ; read publisher

uid=${author// }$(date +%Y)${title// }

# set language rules
echo -n "Choose language [en/fr]: " ; read lang
if [ ! -r "$scriptpath/lang/sed_$lang.txt" ] ;
then
 senderror "Unsupported language"
fi

# preparing headers
cat "$scriptpath/data/header.txt" | sed -e "s/\$title/$title/g" > "$scriptpath/temp/header.txt"
cat "$scriptpath/data/toc.ncx" | sed -e "s/\$title/$title/g" -e "s/\$author/$author/g" -e "s/\$uid/$uid/g" > "$filepath/toc.ncx"
cat "$scriptpath/data/toc.ncx" | sed -e "s/\$title/$title/g" -e "s/\$author/$author/g" -e "s/\$publisher/$publisher/g" -e "s/\$lang/$lang/g"  -e "s/\$uid/$uid/g" > "$filepath/toc.ncx"

# convert text to html

convertpage $filename
if [ -r $filepath/description.$ext ] ;
then
 echo "Description will be taken from $filepath/description.$ext"
 convertpage description
else
 echo "Description page not found"
fi

if [ -r $filepath/contact.$ext ] ;
then
 echo "Contact informations will be taken from $filepath/contact.$ext"
 convertpage contact
else
 echo "Contact page not found"
fi

if [ -r $filepath/serie.$ext ] ;
then
 echo "Serie informations will be taken from $filepath/serie.$ext"
 convertpage serie
else
 echo "Serie page not found"
fi

# replace <hr> with a html entity
echo "Do you want to replace horizontal rules with" ;
echo -n "a single html entity? [y/n] " ; read replacehr
if [[ "$replacehr" == [yY] ]] ;
then
  echo -n "Choose the html entity to use: " ; read hr
  case ${#hr} in
  0)
    senderror "No html entity was provided"
  ;;
  1)
    hr=$(echo "$hr" | recode u8..html)
    if [ ${#hr} = 1 ]
    then
      senderror "$hr is not a valid html entity"
    fi
    hr="\\$hr"
    sed -i "s/<hr>/\n<p class=\"hr\">$hr<\/p>\n/g" $workingname.html
  ;;
  *)
    if [[ ! $hr =~ ^\& ]];
    then
      hr="&$hr"
    fi
    if [[ ${hr: -1} != ";" ]];
    then
      hr="$hr;"
    fi
    hrcheck=$(echo "$hr" | recode html..u8)
    if [ ${#hrcheck} != 1 ]
    then
      senderror "$hr is not a valid html entity"
    fi
    hr="\\$hr"
    sed -i "s/<hr>/\n<p class=\"hr\">$hr<\/p>\n/g" "$workingname.html"
  ;;
  esac
fi

# spliting chapters
csplit -sz -f "$filepath/review/OEBPS/Text/part" "$workingname.html" '/^<h1>/' {*}

# wrapping chapters
chnb="1"
for i in "$filepath/review/OEBPS/Text"/part*
do
 if [ $chnb -lt 10 ]
 then
  prefix="0"
 else
  prefix=""
 fi
 makexhtml $i chap$prefix$chnb
 chnb=$(( chnb + 1 ))
done

rm "$filepath"/review/OEBPS/Text/part*

# writing optionnal pages
if [ -r "$filepath/description.$ext" ] ;
then
 makexhtml "$scriptpath/temp/description.html" title_page
fi
if [ -r "$filepath/description.$ext" ] ;
then
 makexhtml "$scriptpath/temp/contact.html" contact
fi
if [ -r "$filepath/description.$ext" ] ;
then
 makexhtml "$scriptpath/temp/serie.html" serie
fi

#making toc.ncx
#FIXME: handling depth
#FIXME: translations
nav=1
if [ -r "$filepath/review/OEBPS/Text/title_page.xhtml" ] ;
then
 makenavpoint $nav "Title Page" "title_page"
 nav=$(( nav + 1 ))
fi
for i in "$filepath"/review/OEBPS/Text/chap*
do
 makenavpoint $nav "Chapter $nav" "chapter-$nav"
 nav=$(( nav + 1 ))
done
if [ -r "$filepath/review/OEBPS/Text/serie.xhtml" ] ;
then
 makenavpoint $nav "Serie" "serie"
 nav=$(( nav + 1 ))
fi
if [ -r "$filepath/review/OEBPS/Text/contact.xhtml" ] ;
then
 makenavpoint $nav "About $author" "contact"
 nav=$(( nav + 1 ))
fi
echo -e "  </navMap>\n</ncx>" >> "$filepath/review/OEBPS/toc.ncx"

#making content.opf
if [ -r "$filepath/review/OEBPS/Text/title_page.xhtml" ] ;
then
 echo "     <item href=\"Text/title_page.xhtml\" id=\"title_page.xhtml\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
fi
for i in "$filepath"/review/OEBPS/Text/chap*
do
 echo "     <item href=\"Text/$i\" id=\"$i\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
done
if [ -r "$filepath/review/OEBPS/Text/serie.xhtml" ] ;
then
 echo "     <item href=\"Text/serie.xhtml\" id=\"serie.xhtml\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
fi
if [ -r "$filepath/review/OEBPS/Text/contact.xhtml" ] ;
then
 echo "     <item href=\"Text/contact.xhtml\" id=\"contact.xhtml\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
fi
echo -e "    <item href=\"toc.ncx\" id=\"ncx\" media-type=\"application/x-dtbncx+xml\"/>" >> "$filepath/review/OEBPS/content.opf"
echo -e "    <item href=\"Styles/page-template.xpgt\" id=\"page-template.xpgt\" media-type=\"application/vnd.adobe-page-template+xml\"/>" >> "$filepath/review/OEBPS/content.opf"
echo -e "    <item href=\"Styles/stylesheet.css\" id=\"stylesheet.css\" media-type=\"text/css\"/>" >> "$filepath/review/OEBPS/content.opf"
echo -e "  </manifest>\n  <spine toc=\"ncx\">" >> "$filepath/review/OEBPS/content.opf"
if [ -r "$filepath/review/OEBPS/Text/title_page.xhtml" ] ;
then
 echo "    <itemref idref=\"title_page.xhtml\"/>" >> "$filepath/review/OEBPS/content.opf"
fi
for i in "$filepath"/review/OEBPS/Text/chap*
do
 echo "    <itemref idref=\"$i\"/>" >> "$filepath/review/OEBPS/content.opf"
done
if [ -r "$filepath/review/OEBPS/Text/serie.xhtml" ] ;
then
 echo "    <itemref idref=\"serie.xhtml\"/>" >> "$filepath/review/OEBPS/content.opf"
fi
if [ -r "$filepath/review/OEBPS/Text/contact.xhtml" ] ;
then
 echo "    <itemref idref=\"contact.xhtml\"/>" >> "$filepath/review/OEBPS/content.opf"
fi
echo -e "  </spine>\n  <guide/>\n</package>" >> "$filepath/review/OEBPS/content.opf"

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
  if [ -d "$scriptpath/temp" ]; then
   rm -r "$scriptpath/temp" ;
  fi
 exit 1 ;
}

function convertpage()
{
 sed -f "lang/sed_$lang.txt" "$filepath/$1.$ext" > "$scriptpath/temp/$1.tmp"
 sed -i ':a;N;$!ba;s/\n/  \n/g' "$scriptpath/temp/$1.tmp"
 sed -i ':a;N;$!ba;s/  \n  \n/\n\n/g' "$scriptpath/temp/$1.tmp"
 recode -dt u8..h0 "$scriptpath/temp/$1.tmp"
 perl "$scriptpath/markdown.pl" "$scriptpath/temp/$1.tmp" > "$scriptpath/temp/$1.html"
}

function makexhtml()
{
 cat "$scriptpath/temp/header.txt" > "$filepath/review/OEBPS/Text/$2.xhtml"
 cat $1 >> "$filepath/review/OEBPS/Text/$2.xhtml"
 echo "</body></html>" >> "$filepath/review/OEBPS/Text/$2.xhtml"
}

function makenavpoint()
{
 echo -e "    <navPoint id=\"navPoint-$1\" playOrder=\"$1\">" >> "$filepath/review/OEBPS/toc.ncx"
 echo -e "      <navLabel>\n        <text>$2</text>\n      </navLabel>" >> "$filepath/review/OEBPS/toc.ncx"
 echo -e "     <content src=\"Text/$3\"/>\n    </navPoint>" >> "$filepath/review/OEBPS/toc.ncx"
}

scriptpath=`dirname $0`
nav=1
# check if file exist
if [ ! -z $1 ]; then
  filepath=`dirname $1`
  filename=$(basename "$1")
  ext="${filename##*.}"
  filename="${filename%.*}"
  workingname="$scriptpath"/temp/"$filename"
  if [ ! -r $filepath/$filename.$ext ]; then
    senderror "$filename.$ext can't be read!"
  fi
else
  senderror "You must supply the file to convert"
fi
mkdir "$scriptpath/temp"
mkdir -p "$filepath/review/META-INF"
mkdir -p "$filepath/review/OEBPS/Styles"
mkdir -p "$filepath/review/OEBPS/Text"
cp "$scriptpath/data/mimetype" "$filepath/review/"
cp "$scriptpath/data/container.xml" "$filepath/review/META-INF/"
cp "$scriptpath/data/page-template.xpgt" "$filepath/review/OEBPS/Styles/"
cp "$scriptpath/data/stylesheet.css" "$filepath/review/OEBPS/Styles/"
cp "$scriptpath/data/content2.opf" "$filepath/review/OEBPS/"

# check if file is text and markdown
if ! file --mime-type "$1" | grep -q text/plain$; then
  echo "WARNING :$filename.$ext does not look like plain text"
  echo -n "Do you want to continue [y/n] ? " ; read textfile
  if [[ "$textfile" != [yY] ]]; then
    exit 1
  elif [[ "$ext" != md && "$ext" != markdown && "$ext" != mdown && "$ext" != mkdn && "$ext" != mkd && "$ext" != mdwn && "$ext" != mdtxt && "$ext" != mdtext] ]]; then
    echo "File doesn't use have a markdown extension."
    echo -n "Do you wish to continue? [y/n] ?" ; read markdown
    if [[ $markdown != [yY] ]]; then
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
if [ ! -r "$scriptpath/lang/sed_$lang.txt" ]; then
 senderror "Unsupported language"
fi

# preparing headers
cat "$scriptpath/data/header.txt" | sed -e "s/\$title/$title/g" > "$scriptpath/temp/header.txt"
cat "$scriptpath/data/toc.ncx" | sed -e "s/\$title/$title/g" -e "s/\$author/$author/g" -e "s/\$uid/$uid/g" > "$filepath/review/OEBPS/toc.ncx"
cat "$scriptpath/data/content.opf" | sed -e "s/\$title/$title/g" -e "s/\$author/$author/g" -e "s/\$publisher/$publisher/g" -e "s/\$lang/$lang/g"  -e "s/\$uid/$uid/g" > "$filepath/review/OEBPS/content.opf"

# working
if [ -r $filepath/description.$ext ]; then
 echo "Description will be taken from $filepath/description.$ext"
 convertpage description
 makexhtml "$scriptpath/temp/description.html" title_page
 makenavpoint $nav "Title Page" "title_page.xhtml"
 nav=$(( nav + 1 ))
 echo "     <item href=\"Text/title_page.xhtml\" id=\"title_page.xhtml\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
 echo "    <itemref idref=\"title_page.xhtml\"/>" >> "$filepath/review/OEBPS/content2.opf"
else
 echo "Description page not found"
fi

convertpage $filename

echo "Do you want to replace horizontal rules with" ;
echo -n "a single html entity? [y/n] " ; read replacehr
if [[ "$replacehr" == [yY] ]]; then
  echo -n "Choose the html entity to use: " ; read hr
  case ${#hr} in
  0)
    senderror "No html entity was provided"
  ;;
  1)
    hr=$(echo "$hr" | recode u8..h0)
    if [ ${#hr} = 1 ]; then
      senderror "$hr is not a valid html entity"
    fi
    hr="\\$hr"
    sed -i "s/<hr>/\n<p class=\"hr\">$hr<\/p>\n/g" $workingname.html
  ;;
  *)
    if [[ ! $hr =~ ^\& ]]; then
      hr="&$hr"
    fi
    if [[ ${hr: -1} != ";" ]]; then
      hr="$hr;"
    fi
    hrcheck=$(echo "$hr" | recode html..u8)
    if [ ${#hrcheck} != 1 ]; then
      senderror "$hr is not a valid html entity"
    fi
    hr="\\$hr"
    sed -i "s/<hr>/\n<p class=\"hr\">$hr<\/p>\n/g" "$workingname.html"
  ;;
  esac
fi

csplit -sz -f "$filepath/review/OEBPS/Text/part" "$workingname.html" '/^<h1>/' {*}

chnb="1"
for i in "$filepath/review/OEBPS/Text"/part*
do
 if [ $chnb -lt 10 ]; then
  prefix="0"
 else
  prefix=""
 fi
 j=chap$prefix$chnb
 makexhtml $i $j
 chnb=$(( chnb + 1 ))
 makenavpoint $nav "Chapter $nav" "$(basename "$j").xhtml"
 nav=$(( nav + 1 ))
 echo "     <item href=\"Text/$(basename "$j").xhtml\" id=\"$(basename "$j")\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
 echo "    <itemref idref=\"$(basename "$j")\"/>" >> "$filepath/review/OEBPS/content2.opf"
done

if [ -r $filepath/serie.$ext ]; then
 echo "Serie informations will be taken from $filepath/serie.$ext"
 convertpage serie
 makexhtml "$scriptpath/temp/serie.html" serie
 makenavpoint $nav "Serie" "serie.xhtml"
 nav=$(( nav + 1 ))
 echo "     <item href=\"Text/serie.xhtml\" id=\"serie.xhtml\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
 echo "    <itemref idref=\"serie.xhtml\"/>" >> "$filepath/review/OEBPS/content2.opf"
else
 echo "Serie page not found"
fi

if [ -r $filepath/contact.$ext ]; then
 echo "Contact informations will be taken from $filepath/contact.$ext"
 convertpage contact
 makexhtml "$scriptpath/temp/contact.html" contact
 makenavpoint $nav "About $author" "contact.xhtml"
 nav=$(( nav + 1 ))
 echo "     <item href=\"Text/contact.xhtml\" id=\"contact.xhtml\" media-type=\"application/xhtml+xml\" />" >> "$filepath/review/OEBPS/content.opf"
 echo "    <itemref idref=\"contact.xhtml\"/>" >> "$filepath/review/OEBPS/content2.opf"
else
 echo "Contact page not found"
fi

# wrapping up
cat "$filepath/review/OEBPS/content2.opf" >> "$filepath/review/OEBPS/content.opf"
rm "$filepath/review/OEBPS/content2.opf"
echo -e "  </spine>\n  <guide/>\n</package>" >> "$filepath/review/OEBPS/content.opf"
echo -e "  </navMap>\n</ncx>" >> "$filepath/review/OEBPS/toc.ncx"
rm "$filepath"/review/OEBPS/Text/part*
rm -r $scriptpath/temp
cd "$filepath/review"
zip -X -0 "$filepath/${title// }.epub.zip" mimetype
zip -X -9 -r "$filepath/${title// }.epub.zip" * -x mimetype
mv "$filepath/${title// }.epub.zip" "$filepath/${title// }.epub"
#rm -r $filepath/review


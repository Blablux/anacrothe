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
 cat "$scriptpath/temp/header.txt" > "$filepath/Text/$2.xhtml"
 cat $1 >> "$filepath/Text/$2.xhtml"
 echo "</body></html>" >> "$filepath/Text/$2.xhtml"
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
mkdir "$scriptpath"/temp
cat "$scriptpath/data/header.txt" | sed -e "s/\$title/$title/g" > "$scriptpath/temp/header.txt"

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
echo "Description will be taken from $filepath/description.$ext"
echo "Contact informations will be taken from $filepath/contact.$ext"
echo "Serie informations will be taken from $filepath/serie.$ext"

# set language rules
echo -n "Choose language [en/fr]: " ; read lang
if [ ! -r "$scriptpath/lang/sed_$lang.txt" ] ;
then
 senderror "Unsupported language"
fi

# convert text to html

convertpage $filename

if [ -r $filepath/description.$ext ] ;
then
 convertpage description
fi

if [ -r $filepath/contact.$ext ] ;
then
 convertpage contact
fi

if [ -r $filepath/serie.$ext ] ;
then
 convertpage serie
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
mkdir $filepath/Text
csplit -sz -f "$filepath/Text/part" "$workingname.html" '/^<h1>/' {*}

# wrapping chapters

chnb="1"
for i in "$filepath"/Text/part*
do
 if [ $chnb -lt 10 ]
 then
  prefix="0"
 else
  prefix=""
 fi
 makexhtml $i chap$prefix$chnb
# cat "$scriptpath/temp/header.txt" > "$filepath/Text/chap$prefix$chnb.xhtml"
# cat $i >> "$filepath/Text/chap$prefix$chnb.xhtml"
# echo "</body></html>" >> "$filepath/Text/chap$prefix$chnb.xhtml"
 chnb=$(( chnb + 1 ))
done

rm "$filepath"/Text/part*

# writing title page
if [ -r "$filepath/description.$ext" ] ;
then
 makexhtml "$scriptpath/temp/description.html" title_page
# cat "$scriptpath/temp/header.txt" > "$filepath/Text/title_page.xhtml"
# cat "$scriptpath/temp/description.html" >> "$filepath/Text/title_page.xhtml"
# echo "</body></html>" >> "$filepath/Text/title_page.xhtml"
fi

# writing contact page
if [ -r "$filepath/description.$ext" ] ;
then
 makexhtml "$scriptpath/temp/contact.html" contact
# cat "$scriptpath/temp/header.txt" > "$filepath/Text/contact.xhtml"
# cat "$scriptpath/temp/contact.html" >> "$filepath/Text/contact.xhtml"
# echo "</body></html>" >> "$filepath/Text/contact.xhtml"
fi

# writing serie page
if [ -r "$filepath/description.$ext" ] ;
then
 makexhtml "$scriptpath/temp/serie.html" serie
# cat "$scriptpath/temp/header.txt" > "$filepath/Text/serie.xhtml"
# cat "$scriptpath/temp/serie.html" >> "$filepath/Text/serie.xhtml"
# echo "</body></html>" >> "$filepath/Text/serie.xhtml"
fi



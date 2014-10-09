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
  rm -r ./temp ;
  exit 1 ;
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
mkdir ./temp

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

# apply language rules
echo -n "Choose language [en/fr]: " ; read lang
case $lang in
  en|fr)
   sed -f lang/sed_$lang.txt $1 > $workingname.tmp
   sed -f lang/sed_$lang.txt $filepath/description.$ext > ./temp/description.tmp
   ;;
  *) senderror "Unsupported language" ;;
esac

# force line break when you forget them
sed -i ':a;N;$!ba;s/\n/  \n/g' $workingname.tmp
sed -i ':a;N;$!ba;s/  \n  \n/\n\n/g' $workingname.tmp

# convert text to html
recode -dt u8..html $workingname.tmp
recode -dt u8..html ./temp/description.tmp
perl $scriptpath/markdown.pl --html4tags $workingname.tmp > $workingname.html
perl $scriptpath/markdown.pl --html4tags ./temp/description.tmp > ./description.html

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
    sed -i "s/<hr>/\n<p class=\"hr\">$hr<\/p>\n/g" $workingname.html
  ;;
  esac
fi

# spliting chapters
rm $workingname.tmp
mkdir $filepath/Text
csplit -sz -f "$filepath/Text/part" $workingname.html '/^<h1>/' {*}
rm $workingname.html

# wrapping chapters

chnb="1"
cat "$scriptpath/data/header.txt" | sed -e "s/\$title/$title/g" > "$filepath/Text/header.txt"
for i in "$filepath"/Text/part*
do
 if [ $chnb -lt 10 ]
 then
  prefix="0"
 else
  prefix=""
 fi
 cat "$filepath/Text/header.txt" > "$filepath/Text/chap$prefix$chnb.xhtml"
 cat $i >> "$filepath/Text/chap$prefix$chnb.xhtml"
 echo "</body></html>" >> "$filepath/Text/chap$prefix$chnb.xhtml"
 chnb=$(( chnb + 1 ))
done

rm "$filepath"/Text/part*

# writing title page


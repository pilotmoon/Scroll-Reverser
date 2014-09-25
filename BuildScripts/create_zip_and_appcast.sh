# For running in post-build step in scheme.
# Zips app and creates an appcast entry.
echo "In script"
pwd

scripts_dir=`dirname $0`
rnotes_file=$1


echo "Scripts dir ${scripts_dir}"
echo "Scripts dir ${rnotes_file}"

buddy='/usr/libexec/PlistBuddy'
plist=${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}

# get the version label
version=`$buddy -c "Print :CFBundleShortVersionString" "$plist"`

# get the various paths and file names
zipname=`echo "$PRODUCT_NAME-$version.zip" | tr -d ' '`
folder=$BUILT_PRODUCTS_DIR
appname=$FULL_PRODUCT_NAME
product_lowercase=`echo $PRODUCT_NAME | tr '[A-Z]' '[a-z]' | tr -d ' '`

# go to folder and remove existing zips and txt files
cd "$folder"
ls
echo "removing zip and txt files"
rm -f -v *.zip
rm -f -v *.txt
echo "done zip and txt files"

# check that the app is signed
codesign -d -vvvv "$appname"
codesign -vvvv "$appname"
if [[ $? -ne 0 ]]; then
    echo "App is not signed."
    exit 1
else 
    echo "App is signed."
fi

# create zip file for distribution (-r recursive; -y preserve symlinks)
echo "Creating $zipname in $folder from $appname"
zip -r -y -q "$zipname" "$appname"

# filesize
filesize=`stat -f %z "$zipname"`
echo "Filesize: $filesize"

# date
pubdate=`date "+%a, %d %h %Y %T %z"`
echo "Date: $pubdate"
# version num
ver_num=`$buddy -c "Print :CFBundleVersion" "$plist"`
echo "Ver: $ver_num"

# system version
systemversion=`$buddy -c "Print :LSMinimumSystemVersion" "$plist"`
echo "Min system version: $systemversion"

echo "Building Release Notes"

pushd .
cd `dirname $rnotes_file`
rnotes=`erb $scripts_dir/rnotes.erb`
#rnotes=`php -r "echo htmlentities('$rnotes');"`
popd

# create appcast
appcast="appcast-$version.txt"
rm -f $appcast
echo "Creating $appcast"

downloads_webfolder='https://pilotmoon.com/downloads'


echo "<item>" >> $appcast
echo "  <title>Version $version</title>" >> $appcast
echo "  <pubDate>$pubdate</pubDate>" >> $appcast
echo "  <sparkle:minimumSystemVersion>$systemversion</sparkle:minimumSystemVersion>" >> $appcast
echo "  <enclosure url=\"$downloads_webfolder/$zipname\"" >> $appcast
echo "    sparkle:version=\"$ver_num\"" >> $appcast
echo "    sparkle:shortVersionString=\"$version\"" >> $appcast
echo "    length=\"$filesize\"" >> $appcast
echo "    type=\"application/octet-stream\" />" >> $appcast
echo "  <description><![CDATA[$rnotes]]></description>" >> $appcast
echo "</item>" >> $appcast


open $folder


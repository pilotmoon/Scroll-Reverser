# Call as ${SRCROOT}/BuildScripts/create_zip.sh
# version string (e.g. 1.0.2-dev-1-g35d3b126)

buddy='/usr/libexec/PlistBuddy'
plist=${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}

# get the version label
git='/usr/bin/git'
version=`$git describe --dirty`
if [ ${CONFIGURATION} == 'Debug' ]
then
    version="$version-debug"
fi

# get the various paths and file names
zipname="$PRODUCT_NAME-$version.zip"
folder=$BUILT_PRODUCTS_DIR
appname=$FULL_PRODUCT_NAME
product_lowercase=`echo $PRODUCT_NAME | tr '[A-Z]' '[a-z]'`

# go to folder and remove existing zip if there is one
cd "$folder"
rm -f "$zipname"

# create zip file for distribution (-r recursive; -y preserve symlinks)
echo "Creating $zipname in $folder from $appname"
zip -r -y "$zipname" "$appname"

if [ ${CONFIGURATION} == 'Release' ]
then

    # get values for appcast
    echo "Creating appcast entry"

# get path to key (NM_SPARKLE_KEYS_FOLDER should be set globally)
    key="$NM_SPARKLE_KEYS_FOLDER/${product_lowercase}_dsa_priv.pem"
    echo "Using private key $key"

# creat signature (based on sign_update.rb in Sparkle package)
    dsasignature=`openssl dgst -sha1 -binary < $zipname | openssl dgst -dss1 -sign $key | openssl enc -base64`
    
    echo "Signature: $dsasignature"
    
# filesize
    filesize=`stat -f %z $zipname`
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
    
# create appcast
    appcast="appcast-$version.txt"
    rm -f $appcast
    echo "Creating $appcast"

    release_notes_webfolder="http://softwareupdate.pilotmoon.com/update/$product_lowercase/notes"
    downloads_webfolder='http://cdn.downloads.pilotmoon.com'

    echo "<item>" >> $appcast
    echo "  <title>Version $tag</title>" >> $appcast
    echo "  <sparkle:minimumSystemVersion>$systemversion</sparkle:minimumSystemVersion>" >> $appcast
    echo "  <sparkle:releaseNotesLink>" >> $appcast
    echo "    $release_notes_webfolder/$ver_num.html" >> $appcast
    echo "  </sparkle:releaseNotesLink>" >> $appcast
    echo "  <pubDate>$pubdate</pubDate>" >> $appcast
    echo "  <enclosure url=\"$downloads_webfolder/$zipname\"" >> $appcast
    echo "    sparkle:version=\"$ver_num\"" >> $appcast
    echo "    sparkle:shortVersionString=\"$version\"" >> $appcast
    echo "    sparkle:dsaSignature=\"$dsasignature\"" >> $appcast
    echo "    length=\"$filesize\"" >> $appcast
    echo "    type=\"application/octet-stream\" />" >> $appcast
    echo "</item>" >> $appcast

    open $folder

fi

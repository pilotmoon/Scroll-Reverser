echo "Building Release Notes"

buddy='/usr/libexec/PlistBuddy'
plist=${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}

#get version num
ver_num=`$buddy -c "Print :CFBundleVersion" "$plist"`
echo "Ver: $ver_num"

erb ${SRCROOT}/BuildScripts/rnotes.erb > $BUILT_PRODUCTS_DIR/$ver_num.html
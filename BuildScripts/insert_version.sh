# This script fixes up the CFBundleShortVersionString with a string derived from git.
# Place it as a Build Phase just before Copy Bundle Resources

if [[ "$1" ]]; then
	clean=$1
else 
	clean='noclean'
fi

echo "clean setting: $clean"

if [[ "$2" ]]; then
	buildnum_offset=$2
else 
	buildnum_offset='0'
fi

echo "build number offset: $buildnum_offset"

# PlistBuddy and git executables
buddy='/usr/libexec/PlistBuddy'
git='/usr/bin/git'

# the plist files and keys to replace
plist="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
sym_plist="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}.dSYM/Contents/Info.plist"

key='CFBundleShortVersionString'
num_key='CFBundleVersion'
record_key='NMOriginalBundleShortVersionString'

#build number (needs first commit to be tagged 'buildbase')
buildbase_string=`$git describe --match buildbase`
buildnum=`echo "$buildbase_string" | sed 's/buildbase\-//' | sed 's/-g.*//'`
echo "build number from git is $buildnum"
buildnum=`expr $buildnum + $buildnum_offset`
echo "adjusted build number is $buildnum"

# version string
version=`$git describe --dirty --tags`
echo "build number from git is $version"

# add debug suffix if debug
if [[ "${CONFIGURATION}" == 'Debug' ]]; then
	echo "it is a debug build, appending -d"
    version="$version-d"
fi

# add the key to record the original version string
echo "Setting $record_key to $version in $plist"
$buddy -c "Delete :$record_key" "$plist"
$buddy -c "Add :$record_key string $version" "$plist"

# clean string if indicated
if [[ "$clean" == "clean" ]]; then
  # version string for release builds  (strip off everything after dash, e.g. 1.0.2)
  # i do this so that i can test appstore submission on builds tagged e.g. 1.0.2-test1 
  clean_version=`echo $version | sed 's/\-.*//'`
  echo "Cleaning version string from $version to $clean_version"
  version=$clean_version
fi

# do the replacement
echo "Setting $key to $version in $plist"
$buddy -c "Set :$key $version" "$plist"

echo "Setting $key to $version in $sym_plist"
$buddy -c "Set :$key $version" "$sym_plist"

echo "Setting $num_key to $buildnum in $plist"
$buddy -c "Set :$num_key $buildnum" "$plist"

echo "Setting $num_key to $buildnum in $sym_plist"
$buddy -c "Set :$num_key $buildnum" "$sym_plist"


# This script fixes up the CFBundleShortVersionString with a string derived from git.
# Place it as a Build Phase just before Copy Bundle Resources

# clone: git submodule add git@gist.github.com:1151287.git gist-1151287
# call:  ${SRCROOT}/gist-1151287/insert_version.sh

# PlistBuddy and git executables
buddy='/usr/libexec/PlistBuddy'
git='/usr/bin/git'

# the plist file and key to replace
plist=${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}
key='CFBundleShortVersionString'

# version string
version=`$git describe --dirty`
if [ ${CONFIGURATION} == 'Debug' ]
then
    version="$version-d"
fi

# clean string if Release build
if [ $1 == 'clean' ]
then
  # version string for release builds  (strip off everything after dash, e.g. 1.0.2)
  # i do this so that i can test appstore submission on builds tagged e.g. 1.0.2-test1 
  clean_version=`echo $version | sed 's/\-.*//'`
  echo "Cleaning version string from $version to $clean_version"
  version=$clean_version
fi

# do the replacement
echo "Setting $key to $version in Info.plist"
$buddy -c "Set :$key $version" "$plist"

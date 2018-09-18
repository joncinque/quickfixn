#!/usr/bin/env bash

usage() {
  echo "Usage: package_release.sh [VERSION] [S3_ACCESS_KEY] [S3_SECRET_KEY]"
  exit 1
}

TAG_VERSION=$1
[ -z "$TAG_VERSION" ] && usage

echo "==QuickFIX/N Package release script=="
echo "tag version: $TAG_VERSION"
echo

CSPROJ_FILES="QuickFIXn/QuickFix.csproj Messages/FIX40/QuickFix.FIX40.csproj Messages/FIX41/QuickFix.FIX41.csproj Messages/FIX42/QuickFix.FIX42.csproj Messages/FIX43/QuickFix.FIX43.csproj Messages/FIX44/QuickFix.FIX44.csproj Messages/FIX50/QuickFix.FIX50.csproj Messages/FIX50SP1/QuickFix.FIX50SP1.csproj Messages/FIX50SP2/QuickFix.FIX50SP2.csproj"
# Updating the assembly version
for fil in $CSPROJ_FILES
do
  sed -i "s#<Version>.*</Version>#<Version>$TAG_VERSION</Version>#" "$fil"
done
echo "* csproj updated for new version number."

# Add release notes
RELEASE_NOTES=$(git log "$(git describe --tags --abbrev=0)"..HEAD --no-merges --pretty=format:'* %s' | tr '\n' ' ' | sed "s/&/and/")
for fil in $CSPROJ_FILES
do
  sed -i "s+<PackageReleaseNotes>.*</PackageReleaseNotes>+<PackageReleaseNotes>New in $TAG_VERSION: \"$RELEASE_NOTES\"</PackageReleaseNotes>+" "$fil"
done
echo "* csproj updated for package release notes."

# commit the version file, so it will be part of the tag
for fil in $CSPROJ_FILES
do
  git add "$fil"
done
git commit -m "version number for version $TAG_VERSION"
echo "* Version number committed."

# create the tag
git tag -a "$TAG_VERSION" -m "Release version $TAG_VERSION"
echo "* Created tag."

# Get requested version
git checkout "$TAG_VERSION"
RESULT=$?
[ $RESULT -ne 0 ] && echo "There was an error checking out QuickFIX/n $TAG_VERSION" && exit $RESULT
echo "* Checked out tag."

# Generate code from dd
ruby generator/generate.rb
RESULT=$?
[ $RESULT -ne 0 ] && echo "There was an error generating code from the data dictionaries" && exit $RESULT
echo "* Generated code."

# Build and package all QuickFIX/n 
dotnet pack -c Release
RESULT=$?
[ $RESULT -ne 0 ] && echo "There was an error building QuickFIX/n" && exit $RESULT
echo "* Built QuickFIX/n."

# Copy files to temp directory
#QF_DIR=quickfixn-$TAG_VERSION
#[ -d tmp ] && rm -rf tmp
#mkdir tmp
#mkdir tmp/"$QF_DIR"
#mkdir tmp/"$QF_DIR"/bin
#mkdir tmp/"$QF_DIR"/bin/netstandard2.0
#mkdir tmp/"$QF_DIR"/spec
#mkdir tmp/"$QF_DIR"/config
#cp QuickFIXn/bin/Release/netstandard2.0/QuickFix.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.dll
#cp Messages/FIX40/bin/Release/netstandard2.0/QuickFix.FIX40.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX40.dll
#cp Messages/FIX41/bin/Release/netstandard2.0/QuickFix.FIX41.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX41.dll
#cp Messages/FIX42/bin/Release/netstandard2.0/QuickFix.FIX42.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX42.dll
#cp Messages/FIX43/bin/Release/netstandard2.0/QuickFix.FIX43.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX43.dll
#cp Messages/FIX44/bin/Release/netstandard2.0/QuickFix.FIX44.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX44.dll
#cp Messages/FIX50/bin/Release/netstandard2.0/QuickFix.FIX50.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX50.dll
#cp Messages/FIX50SP1/bin/Release/netstandard2.0/QuickFix.FIX50SP1.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX50SP1.dll
#cp Messages/FIX50SP2/bin/Release/netstandard2.0/QuickFix.FIX50SP2.dll tmp/"$QF_DIR"/bin/netstandard2.0/QuickFix.FIX50SP2.dll

#cp -R spec/* tmp/"$QF_DIR"/spec
#cp config/sample_acceptor.cfg tmp/"$QF_DIR"/config
#cp config/sample_initiator.cfg tmp/"$QF_DIR"/config
#cp RELEASE_README.md tmp/"$QF_DIR"/README.md
#cp LICENSE tmp/"$QF_DIR"
#cp RELEASE_NOTES.md tmp/"$QF_DIR"
#echo "* Copied files to tmp directory."

# Create ZIP
#ZIP_NAME=$QF_DIR.zip
#[ -f "$ZIP_NAME" ] && rm "$ZIP_NAME"
#ruby scripts/create_zip.rb tmp/"$QF_DIR" "$ZIP_NAME"
#RESULT=$?
#[ $RESULT -ne 0 ] && echo "There was an error creating QuickFIX/n ZIP: $ZIP_NAME" && exit $RESULT
#echo "* Created zip."

# Upload ZIP
#ACCESS_KEY=$2
#[ -z "$ACCESS_KEY" ] && usage
#SECRET_KEY=$3
#[ -z "$SECRET_KEY" ] && usage
#ruby scripts/s3_upload.rb "$ZIP_NAME" "$ACCESS_KEY" "$SECRET_KEY"
#RESULT=$?
#[ $RESULT -ne 0 ] && echo "There was an error uploading $ZIP_NAME into the s3" && exit $RESULT
#echo "* Uploaded zip."

# Remove temp directory
#rm -rf tmp
#echo "* Removed tmp directory."

# Switch back to master
git checkout master
echo "* Changed back to master."

echo 
echo "Successfully created QuickFIX/n $TAG_VERSION."
#echo "You can download the zip here: http://quickfixn.s3.amazonaws.com/$ZIP_NAME"
echo "You must commit the new tag and deploy the website"
exit 0

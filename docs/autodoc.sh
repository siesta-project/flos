#!/bin/bash

set -e

# Default options
skip_commit=0

# Create documentation...
# Parse options

# Get top-level directory of repository
top_dir=`git rev-parse --show-toplevel`

# Move to the source top directory
pushd $top_dir

# Ensure that the current repo state is saved...
git stash

# Get latest tag version on master (first we pull)
git checkout master
git pull
tag=`git describe --abbrev=0`
doc_tag=$tag
head_tag=`git describe`

git checkout gh-pages
git pull

while [[ $# -gt 0 ]]; do
    opt=$1
    shift

    case $opt in
	--tag|-t)
	    tag=$1
	    doc_tag=$head_tag
	    shift
	    ;;
	--skip-commit|-sc)
	    skip_commit=1
	    ;;
	*)
	    echo "Unrecognized option: $opt"
	    exit 1
	    ;;
    esac
    
done


# Check if the current documentation is the same
# If so, quit immediately
cur_tag=`head -1 docs/doc.tag`

if [[ $doc_tag == $cur_tag ]]; then
    echo "The current documented tag is the same as the latest available tag."
    echo "Will not update documentation..."
    exit 1
fi

# Now we can safely update the documentation tag
echo "$doc_tag" > docs/doc.tag

# Create a temporary directory
tmpdir=`mktemp -d`
echo "... temporary directory: $tmpdir"

# Create a trap, to circle back
trap "rm -r $tmpdir ; git reset --hard HEAD ; git checkout gh-pages ; popd" SIGINT SIGTERM 1

# Prepare temporary documentation folder where settings are
# stored.
# Essentially this is equivalent to the entire gh-pages branch
docdir=gh-pages-docs

# Create temporary stash
# This is necessary as the docs/doc.tag has been updated.
# Consequently we must *fake* a commit.
hashid=`git stash create`
git archive --prefix=$docdir/ -o $tmpdir/gh-pages.tar.gz $hashid

# Re-create the docs/doc.tag to be able to switch branches
git checkout docs/doc.tag

# Move to the latest committed version
# We first checkout master, in case the user has specified 
# a custom tag
git checkout master
git checkout $tag

# Extract the just created tar of the documentation repository
tar xfz $tmpdir/gh-pages.tar.gz

# Now move into the documentation folder and create the documentation
# that we can then copy to the gh-pages branch
pushd $docdir

theme=ldoc
ldoc .

# tar the html output to an tar.gz file
tar cfz $tmpdir/$theme.tar.gz --directory flos-doc .

popd

# Quick exit if not needed
if [[ $skip_commit -eq 1 ]]; then
    echo "Content of temporary folder: $tmpdir"
    ls -l $tmpdir
    exit 0
fi

rm -r $docdir

# Jump back to the gh-pages branch
git checkout gh-pages

# Remove theme that have been re-created
git rm -rf $theme/*

# Ensure directory exists
mkdir -p $theme

pushd $theme

# Extract theme site here
tar xfz $tmpdir/$theme.tar.gz

popd

# Add the theme again to the repository
git add -f $theme

# Now we can safely update the documentation tag
echo "$doc_tag" > docs/doc.tag

# Add everything (including updated tag)
git add docs/doc.tag

# Create commit
git commit -s -m "Released documentation of $doc_tag"

# Clean-up
rm -r $tmpdir

# Notify how to revert the commit
echo "To uncommit (softly) the documentation do:"
echo "  git reset HEAD~1"
echo "To uncommit the documentation do:"
echo "  git reset --hard HEAD~1"


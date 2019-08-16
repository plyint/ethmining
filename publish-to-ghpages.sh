#!/usr/bin/env bash
#
# This script publishes to the production ethmining.net site.
# It first rebuilds the static site on the gh-pages worktree,
# commits the changes, and then pushes to github.

if [ "`git status -s`" ]
then
    echo "The working directory is dirty. Please commit any pending changes."
    exit 1;
fi

echo "Deleting old publication"
rm -rf public
mkdir public
git worktree prune
rm -rf .git/worktrees/public/

echo "Checking out gh-pages branch into public"
git worktree add -B gh-pages public origin/gh-pages

echo "Removing existing files"
rm -rf public/*

echo "Generating site"
hugo

echo "Copying CNAME file"
cp CNAME public/CNAME

echo "Updating gh-pages branch"
cd public && git add --all && git commit -m "Publishing to gh-pages (publish-to-ghpages.sh)"

echo "Pushing to github"
git push --all

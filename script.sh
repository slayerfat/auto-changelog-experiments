#!/usr/bin/env bash

BUMP=`npm run recommended-bump`

echo The recommended bump is ${BUMP}

echo making package.json copy
cp package.json original.package.json

echo using npm version with no tag
npm --no-git-tag-version version ${BUMP} &>/dev/null
VERSION=`npm run json`

echo altering the CHANGELOG.md
npm run changelog-cli

echo commiting
git add CHANGELOG.md
git commit -m "docs: bump to $VERSION"

echo restoring package.json
mv -f original.package.json package.json

echo npm version
npm version ${BUMP} -m "chore: $VERSION release"

echo pushing
git push --follow-tags

echo altering github release metadata
npm run recommended-bump

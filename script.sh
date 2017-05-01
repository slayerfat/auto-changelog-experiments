#!/usr/bin/env bash

BUMP=`node_modules/conventional-recommended-bump/cli.js -p angular`

echo The recommended bump is ${BUMP}

echo making package.json copy
cp package.json original.package.json

echo using npm version with no tag
npm --no-git-tag-version version ${BUMP} &>/dev/null
VERSION=`cat package.json | node_modules/json/lib/json.js version`

echo altering the CHANGELOG.md
node_modules/conventional-changelog-cli/cli.js -i CHANGELOG.md -s -p angular

echo commiting
git add CHANGELOG.md
git commit -m "docs(changelog): bump to $VERSION"

echo restoring package.json
mv -f original.package.json package.json

echo npm version
npm version ${BUMP} -m "chore(release): $VERSION release"

echo pushing
git push --follow-tags

echo altering github release metadata
node_modules/conventional-github-releaser/cli.js -p angular

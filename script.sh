#!/usr/bin/env bash

BUMP=`node_modules/conventional-recommended-bump/cli.js -p angular`

echo The recommended bump is ${BUMP}

echo using npm version with no tag
npm --no-git-tag-version version ${BUMP} &>/dev/null
VERSION=`cat package.json | node_modules/json/lib/json.js version`

echo altering the CHANGELOG.md
node_modules/conventional-changelog-cli/cli.js -i CHANGELOG.md -s -p angular

echo commiting
git add CHANGELOG.md
git commit -m "docs: bump to $VERSION"

echo npm version
npm version ${BUMP} -m "chore: $VERSION release"

echo pushing
git push --follow-tags

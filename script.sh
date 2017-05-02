#!/usr/bin/env bash

VERSION=
BUMP=

function usage {
  cat <<- _EOF_
  Options
    -p, --pre     Bumps the release as a pre-release.
    -d, --dry-run Executes a dry run of the script.
    -h, --help    This help message.
_EOF_
}

function stopIfBranchPristine {
  TAG=`git rev-list --tags --no-walk --max-count=1`
  COMMITS=`git rev-list ${TAG}..HEAD --count`

  if [[ ${COMMITS} == 0 ]]; then
    echo "No new commits since last tag, aborting."
    exit 1
  fi
}

function findBump {
  if ! BUMP=`node_modules/conventional-recommended-bump/cli.js -p angular`; then
    echo "Unexpected error trying to find the recommended bump"
    exit 1
  fi

  if [[ $1 == dry  ]]
  then
    echo "Finding the recommended bump"
    echo "The recommended bump is" ${BUMP}
    echo
  elif [[ $1 == pre ]]
  then
    BUMP=pre${BUMP}

    echo The bump is now ${BUMP}
  fi
}

function makeFileBackups {
  if [ -a package.json ]; then
    if ! cp package.json original.package.json; then
      echo "Unexpected error trying to copy package.json"
      exit 1
    fi
  fi

  if [ -a CHANGELOG.md ]; then
    if ! cp CHANGELOG.md original.CHANGELOG.md; then
      echo "Unexpected error trying to copy CHANGELOG.md"
      exit 1
    fi
  fi
}

function restorePackageJsonFile {
  if [ -a original.package.json ]; then
    if ! cp -f original.package.json package.json; then
      echo "Unexpected error trying to restore package.json"
      exit 1
    fi
  fi
}

function deletePackageJsonFile {
  if [ -a original.package.json ]; then
    if ! rm original.package.json; then
      echo "Unexpected error trying to delete package.json"
      exit 1
    fi
  fi
}

function restoreChangelogFile {
  if [ -a original.CHANGELOG.md ]; then
    if ! mv -f original.CHANGELOG.md CHANGELOG.md; then
      echo "Unexpected error trying to restore CHANGELOG.md"
      exit 1
    fi
  fi
}

function deleteChangelogBackupFile {
  if [ -a original.CHANGELOG.md ]; then
    if ! rm original.CHANGELOG.md; then
      echo "Unexpected error trying to delete CHANGELOG.md"
      exit 1
    fi
  fi
}

function checkCurrentTag {
  CURRENT_TAG=`git describe --abbrev=0 --tags`

  if [[ $1 == dry  ]]
  then
    echo "Checking the current tag"
    echo "The current tag is ${CURRENT_TAG}"
    echo "The new version tag will be v${VERSION}"

    if [[ ${CURRENT_TAG} =~ v${VERSION}$ ]]; then
      echo "Current tag $CURRENT_TAG conflicts with new tag v$VERSION"
    fi

    echo
  else
    if [[ ${CURRENT_TAG} =~ v${VERSION}$ ]]; then
      echo "Current tag $CURRENT_TAG conflicts with new tag v$VERSION, aborting."
      restorePackageJsonFile
      deleteChangelogBackupFile
      deletePackageJsonFile
      exit 1
    fi
  fi
}

function resetGitBranch {
  echo "Resetting branch!"

  if ! git reset --soft HEAD~$1; then
    echo "Unexpected error resetting the branch"
    exit 1
  fi

  if ! git add CHANGELOG.md package.json; then
    echo "Unexpected error git adding files to back"
    exit 1
  fi
}

function findCurrentNpmVersion {
  HAS_ERROR=0
  if ! npm --no-git-tag-version version ${BUMP} &>/dev/null; then
    echo "Unexpected error calling npm version"
    HAS_ERROR=1
  elif ! VERSION=`cat package.json | node_modules/json/lib/json.js version`; then
    echo "Unexpected error calling json parser"
    HAS_ERROR=1
  fi

  if [[ ${HAS_ERROR} != "0" ]]; then
    echo "There were errors finding the current npm version"
    restorePackageJsonFile
    deleteChangelogBackupFile
    deletePackageJsonFile
    exit 1
  fi

  if [[ $1 == dry  ]]
  then
    echo "Using npm version with no tag"
    echo "npm --no-git-tag-version version ${BUMP} &>/dev/null"
    echo "VERSION=cat package.json | node_modules/json/lib/json.js version"
    echo "The version is" `cat package.json | node_modules/json/lib/json.js version`
    echo

    checkCurrentTag dry
  fi

  checkCurrentTag
}

function alterChangelog {
  if [[ $1 == dry  ]]
  then
    echo "Altering the CHANGELOG.md file"
    echo "node_modules/conventional-changelog-cli/cli.js -i CHANGELOG.md -s -p angular"
    echo `node_modules/conventional-changelog-cli/cli.js -p angular`
    echo
  else
    if ! node_modules/conventional-changelog-cli/cli.js -i CHANGELOG.md -s -p angular; then
      echo "Unexpected error trying to alter the changelog file"
      restorePackageJsonFile
      restoreChangelogFile
      exit 1
    fi
  fi
}

function commitChanges {
  if [[ $1 == dry  ]]
  then
    echo "Committing"
    echo "git add CHANGELOG.md"
    echo "git commit -m docs(changelog): bump to $VERSION"
    echo
  else
    if ! git add CHANGELOG.md; then
      echo "Unexpected error trying to add the changelog file to git"
      restorePackageJsonFile
      deletePackageJsonFile
      deleteChangelogBackupFile
      exit 1
    fi

    if ! git commit -m "docs(changelog): bump to $VERSION"; then
      echo "Unexpected error trying to commit the changelog file to git"
      restorePackageJsonFile
      deletePackageJsonFile
      deleteChangelogBackupFile
      exit 1
    fi
  fi
}

function callNpmBumpVersion {
  restorePackageJsonFile
  if [[ $1 == dry  ]]
  then
    echo "Changing npm version"
    echo "npm version ${BUMP} -m chore(release): %s release"
    echo

    deletePackageJsonFile
  else
    if ! npm version ${BUMP} -m "chore(release): %s release"; then
      echo "Unexpected error trying to use the npm version"
      restorePackageJsonFile
      restoreChangelogFile
      deletePackageJsonFile
      resetGitBranch 1
      exit 1
    fi

    deletePackageJsonFile
  fi
}

function gitPush {
  if [[ $1 == dry  ]]
  then
    echo "Pushing"
    echo "git push --follow-tags"
    echo
  else
    git push --follow-tags
  fi
}

function updateGithubTagMetadata {
  if [[ $1 == dry  ]]
  then
    echo "Altering github release metadata"
    echo "node_modules/conventional-github-releaser/cli.js -p angular"
    echo
  else
    node_modules/conventional-github-releaser/cli.js -p angular
  fi
}

# Main

function main {
  if [[ $1 == dry  ]]
  then
    echo "Starting script as a dry run"
    echo
  fi

  stopIfBranchPristine
  findBump $1
  makeFileBackups
  findCurrentNpmVersion $1
  alterChangelog $1
  commitChanges $1
  callNpmBumpVersion $1
  gitPush $1
  updateGithubTagMetadata $1
  deleteChangelogBackupFile
}

while [ "$1" != "" ]; do
  case $1 in
    -p | --pre )
      main pre
      exit ;;
    -d | --dry-run )
      main dry
      exit ;;
    -h | --help )
      usage
      exit ;;
    * )
      usage
      exit 1
  esac
  shift
done

main

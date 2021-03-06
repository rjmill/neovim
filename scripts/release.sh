#!/usr/bin/env bash

# Performs steps to tag a release.
#
# Steps:
#   Create the "release" commit:
#     - CMakeLists.txt: Unset NVIM_VERSION_PRERELEASE
#     - CMakeLists.txt: Unset NVIM_API_PRERELEASE
#     - Tag the commit.
#   Create the "version bump" commit:
#     - CMakeLists.txt: Set NVIM_VERSION_PRERELEASE to "-dev"
#
# Manual steps:
#   - CMakeLists.txt: Bump NVIM_VERSION_* as appropriate.
#   - git push --follow-tags

set -e
set -u
set -o pipefail

__sed=$( [ "$(uname)" = Darwin ] && echo 'sed -E' || echo 'sed -r' )

cd "$(git rev-parse --show-toplevel)"

__LAST_TAG=$(git describe --abbrev=0)
[ -z "$__LAST_TAG" ] && { echo 'ERROR: no tag found'; exit 1; }
__VERSION_MAJOR=$(grep 'set(NVIM_VERSION_MAJOR' CMakeLists.txt\
  |$__sed 's/.*NVIM_VERSION_MAJOR ([[:digit:]]).*/\1/')
__VERSION_MINOR=$(grep 'set(NVIM_VERSION_MINOR' CMakeLists.txt\
  |$__sed 's/.*NVIM_VERSION_MINOR ([[:digit:]]).*/\1/')
__VERSION_PATCH=$(grep 'set(NVIM_VERSION_PATCH' CMakeLists.txt\
  |$__sed 's/.*NVIM_VERSION_PATCH ([[:digit:]]).*/\1/')
__VERSION="${__VERSION_MAJOR}.${__VERSION_MINOR}.${__VERSION_PATCH}"
{ [ -z "$__VERSION_MAJOR" ] || [ -z "$__VERSION_MINOR" ] || [ -z "$__VERSION_PATCH" ]; } \
  &&  { echo "ERROR: version parse failed: '${__VERSION}'"; exit 1; }
__RELEASE_MSG="NVIM v${__VERSION}

FEATURES:

FIXES:

CHANGES:

"
__BUMP_MSG="version bump"

echo "Most recent tag: ${__LAST_TAG}"
echo "Release version: ${__VERSION}"
$__sed -i.bk 's/(NVIM_VERSION_PRERELEASE) "-dev"/\1 ""/' CMakeLists.txt
$__sed -i.bk 's/(NVIM_API_PRERELEASE) true/\1 false/' CMakeLists.txt
echo "Building changelog since ${__LAST_TAG}..."
__CHANGELOG="$(./scripts/git-log-pretty-since.sh "$__LAST_TAG" 'vim-patch:\S')"

git add CMakeLists.txt
git commit --edit -m "${__RELEASE_MSG} ${__CHANGELOG}"
git tag --sign -a v"${__VERSION}" -m "NVIM v${__VERSION}"

$__sed -i.bk 's/(NVIM_VERSION_PRERELEASE) ""/\1 "-dev"/' CMakeLists.txt
$__sed -i.bk 's/set\((NVIM_VERSION_PATCH) [[:digit:]]/set(\1 ?/' CMakeLists.txt
nvim +'/NVIM_VERSION' +10new +'exe "norm! iUpdate version numbers!!!\<CR>"' \
  +'norm! 10.' CMakeLists.txt

git add CMakeLists.txt
git commit -m "$__BUMP_MSG"

echo "
Next steps:
    - Double-check NVIM_VERSION_* in CMakeLists.txt
    - git push --follow-tags
    - update website: index.html"

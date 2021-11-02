#!/usr/bin/env bash

UPSTREAM_REPO_URL="git@github.com:namespacebrian/custom-upstream-6777.git";
UPSTREAM_REPO_PATH="$HOME/sites/custom-upstream-6777";
UPSTREAM_UUID='ad02c549-ec77-49a4-bcf5-4fb3625bcb0c';
PRE_IC_GIT_REF='b7b25a393a6822f20a597a38ad7505aa869bcca0';
IC_APPLY_GIT_REF='origin/composerify';
ORG_UUID='d3ecc20c-395a-43c4-93ee-f5f43808b6c8';
SITE_NAME_PREFIX='bugs-3935-';

LOCAL_SITES_PATH="";

if [[ ! -d $UPSTREAM_REPO_PATH ]]; then
    echo "Cloning upstream repo...";
    mkdir -p $UPSTREAM_REPO_PATH;
    cd $UPSTREAM_REPO_PATH;
    git clone $UPSTREAM_REPO_URL .;
    cd -;
fi

# Rewind upstream
pushd "$UPSTREAM_REPO_PATH";
git checkout $PRE_IC_GIT_REF;
git branch -D master;
git checkout -b master;
git push --force --set-upstream origin master;


# Create new site
NEW_SITE_NAME="${SITE_NAME_PREFIX}$(echo $RANDOM | md5sum | head -c 6)";
echo "new site name: $NEW_SITE_NAME";
terminus site:create "$NEW_SITE_NAME" "$NEW_SITE_NAME" $UPSTREAM_UUID --org=$ORG_UUID
SITE_CREATE_EXIT_CODE=$?;

if [[ $SITE_CREATE_EXIT_CODE -ne 0 ]]; then
  echo "Failed to create new site";
  exit $SITE_CREATE_EXIT_CODE;
fi;

#RANDOM_PASSWD=$(echo $RANDOM | md5sum | head -c 16);
SITE_INSTALL_CMD="terminus remote:drush ${NEW_SITE_NAME}.dev site-install demo_umami -- --account-name=pantheon_admin --account-mail=brian.weaver@pantheon.io --yes";
echo "Site install cmd: $SITE_INSTALL_CMD";

eval $SITE_INSTALL_CMD;
INSTALL_EXIT_CODE=$?;
echo "Install exit code: $INSTALL_EXIT_CODE";

if [[ $INSTALL_EXIT_CODE -ne 0 ]]; then
  echo "Failed to install new site";
  exit $INSTALL_EXIT_CODE;
fi;

DASHBOARD_URL=$(terminus dashboard:view --print $NEW_SITE_NAME.dev);
echo "Dashboard URL: $DASHBOARD_URL";
open $DASHBOARD_URL;


echo;
echo "Set connection mode to 'git'...";
terminus connection:set ${NEW_SITE_NAME}.dev git
echo;

echo; echo "Create 'test' environment...";
terminus env:deploy ${NEW_SITE_NAME}.test
echo;

echo; echo "Create 'live' environment...";
terminus env:deploy ${NEW_SITE_NAME}.live
echo;

# Apply IC
echo; echo "Apply IC...";
git merge --ff-only $IC_APPLY_GIT_REF;
#MERGE_EXIT_CODE=$?;
git push;
echo;

terminus site:upstream:clear-cache ${NEW_SITE_NAME};
terminus upstream:updates:list ${NEW_SITE_NAME}.dev;
terminus upstream:updates:apply ${NEW_SITE_NAME}.dev --yes;
echo;

popd;

GIT_CLONE_CMD=$(terminus connection:info --fields=git_command --format=string ${NEW_SITE_NAME}.dev);
echo "Git clone cmd: $GIT_CLONE_CMD";



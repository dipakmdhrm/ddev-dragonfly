#!/usr/bin/env bash
#ddev-generated
set -e

if [[ $DDEV_PROJECT_TYPE != drupal* ]] || [[ $DDEV_PROJECT_TYPE =~ ^drupal(6|7)$ ]] ;
then
  for file in dragonfly/scripts/settings.ddev.dragonfly.php dragonfly/scripts/setup-drupal-settings.sh; do
    if grep -q "#ddev-generated" "${file}" 2>/dev/null; then
      echo "Removing ${file} as not applicable"
      rm -f "${file}"
    fi
  done
  exit 0
fi

if ( ddev debug configyaml 2>/dev/null | grep 'disable_settings_management:\s*true' >/dev/null 2>&1 ) ; then
  exit 0
fi

cp dragonfly/scripts/settings.ddev.dragonfly.php $DDEV_APPROOT/$DDEV_DOCROOT/sites/default/

SETTINGS_FILE_NAME="${DDEV_APPROOT}/${DDEV_DOCROOT}/sites/default/settings.php"
echo "Settings file name: ${SETTINGS_FILE_NAME}"
grep -qF 'settings.ddev.dragonfly.php' $SETTINGS_FILE_NAME || echo "
// Include settings required for DragonflyDB cache.
if (getenv('IS_DDEV_PROJECT') == 'true' && file_exists(__DIR__ . '/settings.ddev.dragonfly.php')) {
  include __DIR__ . '/settings.ddev.dragonfly.php';
}" >> $SETTINGS_FILE_NAME

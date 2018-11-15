#!/bin/bash

# Fallback to default values if variables are not set
if [ -z ${APACHE_RUN_USER+x} ]; then
    APACHE_RUN_USER="www-data"
fi
if [ -z ${APACHE_RUN_GROUP+x} ]; then
    APACHE_RUN_GROUP="www-data"
fi
if [ -z ${VHOST_FILE+x} ]; then
    VHOST_FILE="001-unnamed.conf"
fi
if [ -z ${SERVER_ADMIN+x} ]; then
    SERVER_ADMIN="webmaster@webdev.dock"
fi
if [ -z ${SERVER_NAME+x} ]; then
    SERVER_NAME="www.webdev.dock"
fi
if [ -z ${SERVER_ALIAS+x} ]; then
    SERVER_ALIAS="webdev.dock *.webdev.dock"
fi
if [ -z ${DOCUMENT_ROOT+x} ]; then
    DOCUMENT_ROOT="/var/www/html"
fi
if [ -z ${VHOST_EXTRAS+x} ]; then
    VHOST_EXTRAS=""
fi
VHOST_EXTRAS=${VHOST_EXTRAS//$'\n'/\\n}
if [ -z ${DIRECTORY+x} ]; then
    DIRECTORY="$DOCUMENT_ROOT"
fi
if [ -z ${LOG_DIRECTORY+x} ]; then
    LOG_DIRECTORY="$DIRECTORY/logs"
    if [ -z ${LOG_ERROR+x} ]; then
        LOG_ERROR="$LOG_DIRECTORY/error.log"
    fi
    if [ -z ${LOG_CUSTOM+x} ]; then
        LOG_CUSTOM="$LOG_DIRECTORY/access.log combined"
    fi
fi
if [ -z ${LOG_ERROR+x} ]; then
    LOG_ERROR="$LOG_DIRECTORY/error.log"
fi
if [ -z ${LOG_CUSTOM+x} ]; then
    LOG_CUSTOM="$LOG_DIRECTORY/access.log combined"
fi
if [ -z ${LOG_SENDMAIL+x} ]; then
    LOG_SENDMAIL="$LOG_DIRECTORY/sendmail.log"
fi
if [ -z ${DIRECTORY_OPTIONS+x} ]; then
    DIRECTORY_OPTIONS="Indexes Includes FollowSymLinks MultiViews"
fi
if [ -z ${DIRECTORY_EXTRA+x} ]; then
    DIRECTORY_EXTRA="AllowOverride All"
fi
DIRECTORY_EXTRA=${DIRECTORY_EXTRA//$'\n'/\\n}
read -d '' DIRECTORY_PERM_DEFAULT <<"EOF"
    #
    # Controls who can get stuff from this server.
    #
    Order allow,deny
    Allow from all
    Require all granted
EOF
if [ -z ${DIRECTORY_PERM+x} ]; then
    DIRECTORY_PERM=$DIRECTORY_PERM_DEFAULT
fi
DIRECTORY_PERM=${DIRECTORY_PERM//$'\n'/\\n}

# Replace template into new vhost file
cat /var/www/apache-vhost-template.conf | sed \
    -e "s/##SERVER_ADMIN##/${SERVER_ADMIN//\//\\/}/g" \
    -e "s/##SERVER_NAME##/${SERVER_NAME//\//\\/}/g" \
    -e "s/##SERVER_ALIAS##/${SERVER_ALIAS//\//\\/}/g" \
    -e "s/##DOCUMENT_ROOT##/${DOCUMENT_ROOT//\//\\/}/g" \
    -e "s/##VHOST_EXTRAS##/${VHOST_EXTRAS//\//\\/}/g" \
    -e "s/##LOG_ERROR##/${LOG_ERROR//\//\\/}/g" \
    -e "s/##LOG_CUSTOM##/${LOG_CUSTOM//\//\\/}/g" \
    -e "s/##DIRECTORY##/${DIRECTORY//\//\\/}/g" \
    -e "s/##DIRECTORY_OPTIONS##/${DIRECTORY_OPTIONS//\//\\/}/g" \
    -e "s/##DIRECTORY_EXTRA##/${DIRECTORY_EXTRA//\//\\/}/g" \
    -e "s/##DIRECTORY_PERM##/${DIRECTORY_PERM//\//\\/}/g" \
    > /etc/apache2/sites-available/${VHOST_FILE}

# Enable vhost configuration
ln -s /etc/apache2/sites-available/${VHOST_FILE} /etc/apache2/sites-enabled/${VHOST_FILE}

# Use default home directory
if [ -z ${APACHE_RUN_USER_HOME+x} ]; then
    if [ "$APACHE_RUN_USER" == "www-data" ]; then
        APACHE_RUN_USER_HOME="/var/www"
    else
        APACHE_RUN_USER_HOME="/home/$APACHE_RUN_USER"
    fi
fi

APACHE_RUN_UID=""
APACHE_RUN_GID=""
UPDATE_PERMISSIONS="n"
VOLUME_PATHS="$APACHE_RUN_USER_HOME $DOCUMENT_ROOT"

for VOLUME_PATH in $VOLUME_PATHS
do
  #echo "Checking permissions of $VOLUME_PATH ..."
  # Only check permissions if no userid was detected so far
  if [ ! "$APACHE_RUN_UID" ]; then
    CHECK_USER_ID=`stat -c '%u' ${VOLUME_PATH}`
    CHECK_GROUP_ID=`stat -c '%g' ${VOLUME_PATH}`
    # Skip volumes that are owned by root
    if [ "$CHECK_USER_ID" != "0" ] && [ "$CHECK_GROUP_ID" != "0" ]; then
      if [ "$CHECK_USER_ID" != "$APACHE_RUN_UID_DEFAULT" ]; then
        APACHE_RUN_UID="$CHECK_USER_ID"
        APACHE_RUN_GID="$CHECK_GROUP_ID"
      elif [ "$CHECK_GROUP_ID" != "$APACHE_RUN_GID_DEFAULT" ]; then
        APACHE_RUN_GID="$CHECK_GROUP_ID"
      fi
    fi
  fi
done

# Fall back to the default uid/gid if nothing non-root could be detected
if [ ! "$APACHE_RUN_UID" ]; then
  APACHE_RUN_UID="$APACHE_RUN_UID_DEFAULT"
  UPDATE_PERMISSIONS="y"
fi
if [ ! "$APACHE_RUN_GID" ]; then
  APACHE_RUN_GID="$APACHE_RUN_GID_DEFAULT"
  UPDATE_PERMISSIONS="y"
fi

# Check if the desired user id exists
if [ "$APACHE_RUN_USER" != "$PACHE_RUN_USER_DEFAULT" ]; then
  # User id not known or user name changed! Update the default users id to match
  sed -i s/${APACHE_RUN_USER_DEFAULT}:x:[0-9]*:[0-9]*:/${APACHE_RUN_USER}:x:${APACHE_RUN_UID}:${APACHE_RUN_GID}:/ /etc/passwd
  # Update permissions for the volumes before execution
  UPDATE_PERMISSIONS="y"
elif [ "$APACHE_RUN_GID" != "$APACHE_RUN_GID_DEFAULT" ]; then
  # Default group id changed!
  sed -i s/${APACHE_RUN_USER_DEFAULT}:x:[0-9]*:[0-9]*:/${APACHE_RUN_USER}:x:${APACHE_RUN_UID}:${APACHE_RUN_GID}:/ /etc/passwd
fi

# Check if the desired group id exists
if [ "$APACHE_RUN_GROUP" != "$APACHE_RUN_GROUP_DEFAULT" ]; then
  # Group id not known! Update the default groups id to match
  sed -i s/${APACHE_RUN_GROUP_DEFAULT}:x:[0-9]*:/${APACHE_RUN_GROUP}:x:${APACHE_RUN_GID}:/ /etc/group
  # Update permissions for the volumes before execution
  UPDATE_PERMISSIONS="y"
fi

echo "Detected permissions: ${APACHE_RUN_USER} / ${APACHE_RUN_GROUP} (${APACHE_RUN_UID} / ${APACHE_RUN_GID})"

if [ "$UPDATE_PERMISSIONS" = "y" ]; then
  echo -n "Updating volume permissions... "
  for VOLUME_PATH in $VOLUME_PATHS
  do
    chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP "$VOLUME_PATH"
  done
  mkdir -p $APACHE_RUN_USER_HOME
  chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP "$APACHE_RUN_USER_HOME"
  echo "Done!"
fi

# Copy ssh key(s)
if [ ! -z ${APACHE_RUN_USER_SSH_DIR+x} ]; then
    # Add ssh directory to user home
    mv $APACHE_RUN_USER_SSH_DIR $APACHE_RUN_USER_HOME/.ssh
    # Ensure correct permissions for ssh key
    if [ -d $APACHE_RUN_USER_HOME/.ssh ]; then
        chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $APACHE_RUN_USER_HOME/.ssh
        chmod 0700 $APACHE_RUN_USER_HOME/.ssh
        chmod 0600 $APACHE_RUN_USER_HOME/.ssh/*
    fi
fi
# Apply correct permissions to the home directory
chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $APACHE_RUN_USER_HOME

# Pull from git
if [ ! -z ${GIT_SOURCE+x} ]; then
    if [ -z ${GIT_DIRECTORY+x} ]; then
        GIT_DIRECTORY=$DIRECTORY
    fi
    if [ ! -d $GIT_DIRECTORY ]; then
        echo "Project directory does not exist! Cloning from git... ($GIT_DIRECTORY)"
        # Ensure correct permissions for ssh key
        if [ -d $APACHE_RUN_USER_HOME/.ssh ]; then
            chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $APACHE_RUN_USER_HOME/.ssh
            chmod 0700 $APACHE_RUN_USER_HOME/.ssh
            chmod 0600 $APACHE_RUN_USER_HOME/.ssh/*
        fi
        # Ensure access to parent directory
        GIT_DIRECTORY_PARENT=`echo $GIT_DIRECTORY | sed -e "s/\(.*\)\/[^\/]*/\1/"`
        chown $APACHE_RUN_USER:$APACHE_RUN_GROUP $GIT_DIRECTORY_PARENT
        # Clone git repository
        sudo -u $APACHE_RUN_USER git clone $GIT_SOURCE $GIT_DIRECTORY
        # Update composer
        cd $GIT_DIRECTORY
        if [ -f composer.json ]; then
            sudo -u $APACHE_RUN_USER composer update
        fi
    fi
fi

# Enforce existing log directory
mkdir -p $LOG_DIRECTORY
chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $LOG_DIRECTORY

# Enforce correct user rights
chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $DIRECTORY

# Start chronjob
echo "EXTRA_OPTS='-l'" >> /etc/default/cron
/etc/init.d/cron start
/etc/init.d/anacron start

if [ "$#" -ne 0 ]; then
    # Start apache
    touch /var/log/apache2/output.log
    apache2-foreground > /var/log/apache2/output.log 2>&1 &
    
    exec "$@"
fi
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
    LOG_ERROR="/var/log/apache2/error.log"
fi
if [ -z ${LOG_CUSTOM+x} ]; then
    LOG_CUSTOM="/var/log/apache2/access.log combined"
fi
if [ -z ${LOG_SENDMAIL+x} ]; then
    LOG_SENDMAIL="$LOG_DIRECTORY/sendmail.log"
fi
if [ -z ${DIRECTORY_OPTIONS+x} ]; then
    DIRECTORY_OPTIONS="Indexes Includes FollowSymLinks"
fi
if [ -z ${DIRECTORY_EXTRA+x} ]; then
    DIRECTORY_EXTRA="AllowOverride All"
fi
DIRECTORY_EXTRA=${DIRECTORY_PERM//$'\n'/\\n}
read -d '' DIRECTORY_PERM_DEFAULT <<"EOF"
    #
    # Controls who can get stuff from this server.
    #
    Order allow,deny
    Allow from all
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

# Create apache run user
if [ ! -d "$APACHE_RUN_USER_HOME" ]; then
    # Add group
    if [ -z ${APACHE_RUN_GID+x} ]; then
        groupadd $APACHE_RUN_GROUP
    else
        groupadd -g $APACHE_RUN_GID $APACHE_RUN_GROUP
    fi
    # Create home directory
    if [ ! -d $APACHE_RUN_USER_HOME ]; then
        mkdir -p $APACHE_RUN_USER_HOME
    fi
    # Add user
    if [ -z ${APACHE_RUN_UID+x} ]; then
        useradd -d $APACHE_RUN_USER_HOME -g $APACHE_RUN_GID -G $APACHE_RUN_GROUP $APACHE_RUN_USER
    else
        useradd -d $APACHE_RUN_USER_HOME -g $APACHE_RUN_GID -u $APACHE_RUN_UID -G $APACHE_RUN_GROUP $APACHE_RUN_USER
    fi
    # Apply correct permissions to the home directory
    chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $APACHE_RUN_USER_HOME
fi

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

exec "$@"
#!/bin/bash

setup.sh

# Start apache
touch /var/log/apache2/output.log
apache2-foreground > /var/log/apache2/output.log 2>&1 &

exec "$@"
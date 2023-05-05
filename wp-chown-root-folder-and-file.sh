#!/bin/bash
# Author: ThanhN
# Email: nguyenthanhictu@gmail.com
# This is a sample bash script to run chown command for wordpress folders and files
# Get the variables from the command line arguments

USERNAME=${1:-root} # The first argument is the username
GROUPNAME=${2:-root} # The second argument is the group name
DISALLOW_FILE_MODS=${3:-disable} # Disable add new, update, delete plugins and themes [disable, enable]
WORDPRESS=./ # The path to your wordpress folder

# Task 1: Run the chown command with sudo
sudo chown -R $USERNAME:$GROUPNAME ./wp-admin ./wp-includes ./wp-config.php ./.htaccess ./wp-config-sample.php ./wp-settings.php ./wp-login.php ./wp-load.php ./wp-mail.php ./xmlrpc.php ./wp-links-opml.php ./wp-trackback.php ./wp-cron.php ./wp-signup.php ./wp-activate.php ./wp-comments-post.php ./wp-blog-header.php ./index.php

sudo chown -R $USERNAME:$GROUPNAME ./wp-content/plugins ./wp-content/themes ./wp-content/index.php ./wp-content/.htaccess

# Task 2.1: Disable Plugin and Theme Updates and Installs in WordPress
if [ $DISALLOW_FILE_MODS = "disable" ] && grep -q "define('DISALLOW_FILE_MODS', true);" ./wp-config.php; then echo Code already exists; else echo "define('DISALLOW_FILE_MODS', true);" >> ./wp-config.php; fi

# Task 2.2: Enable Plugin and Theme Updates and Installs in WordPress
if [ $DISALLOW_FILE_MODS = "enable" ] && grep -q "define('DISALLOW_FILE_MODS', true);" ./wp-config.php; then sed -i "/define('DISALLOW_FILE_MODS', true);/d" ./wp-config.php;  else echo Code does not exist; fi

# Print a message to confirm the operation
echo "Changed ownership of all folders and files in $WORDPRESS to $USERNAME:$GROUPNAME"
ls -alt

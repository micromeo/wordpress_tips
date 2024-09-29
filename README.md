# wordpress_tips
WordPress Tips

**Example**:

Step 1: Clone sh file
> https://raw.githubusercontent.com/micromeo/wordpress_tips/main/wp-chown-root-folder-and-file.sh

Step 2: Disable/Enable Plugin and Theme
Disable Plugin and Theme Updates and Installs in WordPress
> bash wp-chown-root-folder-and-file.sh root root disable

Enable Plugin and Theme Updates and Installs in WordPress
> bash wp-chown-root-folder-and-file.sh owner owner enable

** Chmod file and folders **
> find public_html/wp-includes -type f -exec chmod 400 {} \;
> find /path/to/wordpress/ -type d -exec chmod 755 {} \;

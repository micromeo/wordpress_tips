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
> 
> find /path/to/wordpress/ -type d -exec chmod 755 {} \;

**Crontab for vps_monitor**

To run the VPS monitor script periodically, add a cron entry. Example (run every minute):

```
* * * * * /root/vps-monitor/vps_monitor.sh >/dev/null 2>&1
```

Place the `vps_monitor.sh` script under `/root/vps-monitor/` (or adjust the path above), make it executable:

```
chmod +x /root/vps-monitor/vps_monitor.sh
```

If you prefer to run it every 5 minutes, use:

```
*/5 * * * * /root/vps-monitor/vps_monitor.sh >/dev/null 2>&1
```

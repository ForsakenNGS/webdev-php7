This image is based on php:7-apache (https://hub.docker.com/r/library/php/)

## Apache

### User / Group configuration

The setup script will check if the **home directory** of the user exists. 
If not the group, user and home directory will be created.
You can optionally provide a user- and group-id to match with your host user for easy integration of mounted volumes. 

- **APACHE_RUN_USER** The user name that apache will run with *(default: "www-data")*
- **APACHE_RUN_GROUP** The group name that apache will run with *(default: "www-data")*
- **APACHE_RUN_USER_HOME** The home directory of the apache user *(default: "/var/www" or "/home/$APACHE_RUN_USER")*
- **APACHE_RUN_UID** The user id that will be used for creating the user *(optional)*
- **APACHE_RUN_GID** The group id that will be used for creating the group *(optional)*

#### VirtualHost entry

By default the container will create a virtual host file and enable it within apache.
For that the following template will be used:

```
#
# VirtualHost template
#
# See /usr/share/doc/packages/apache2/README.QUICKSTART for further hints
# about virtual hosts.
#
<VirtualHost *:80>
    ServerAdmin ##SERVER_ADMIN##
    ServerName ##SERVER_NAME##

    ServerAlias ##SERVER_ALIAS##

    # DocumentRoot: The directory out of which you will serve your
    # documents. By default, all requests are taken from this directory, but
    # symbolic links and aliases may be used to point to other locations.
    DocumentRoot ##DOCUMENT_ROOT##

    ErrorLog ##LOG_ERROR##
    CustomLog ##LOG_CUSTOM##

    HostnameLookups Off

    UseCanonicalName On

    ServerSignature On

    ##VHOST_EXTRAS##

    <Directory "##DIRECTORY##">
        #
        # Possible values for the Options directive are "None", "All",
        # or any combination of:
        #   Indexes Includes FollowSymLinks SymLinksifOwnerMatch ExecCGI MultiViews
        #
        # Note that "MultiViews" must be named *explicitly* --- "Options All"
        # doesn't give it to you.
        #
        # The Options directive is both complicated and important.  Please see
        # http://httpd.apache.org/docs-2.2/mod/core.html#options
        # for more information.
        #
        Options ##DIRECTORY_OPTIONS##

        ##DIRECTORY_EXTRA##

        ##DIRECTORY_PERM##
    </Directory>
</VirtualHost>
```

For the generation of the vhost-file the following environment variables are used:
- **VHOST_FILE** The full filename of the vhost configuration *(Default: "$VHOST_INDEX-$VHOST_NAME.conf" > "001-unnamed.conf")*
- **LOG_DIRECTORY** The directory where the apache logs for this vhost will be located

All placeholders (##SOMETHING##) will be replaced by the respective environment variables. Those are:
- **SERVER_ADMIN** *(Default: "webmaster@webdev.dock")*
- **SERVER_NAME** *(Default: "www.webdev.dock")*
- **SERVER_ALIAS** *(Default: "webdev.dock \*.webdev.dock")*
- **DOCUMENT_ROOT** *(Default: "/var/www/html")*
- **VHOST_EXTRAS** *(Default: "")*
- **LOG_ERROR** *(Default: "$LOG_DIRECTORY/error.log")*
- **LOG_CUSTOM** *(Default: "$LOG_DIRECTORY/access.log combined")*
- **DIRECTORY** *(Default: "$DOCUMENT_ROOT")*
- **DIRECTORY_OPTIONS** *(Default: "Indexes Includes FollowSymLinks")*
- **DIRECTORY_EXTRA** *(Default: "AllowOverride All")*
- **DIRECTORY_PERM** *Default:*
```
    #
    # Controls who can get stuff from this server.
    #
    Order allow,deny
    Allow from all
```

## Shared volumes

To use shared volumes for deployment simply add your project to your **DIRECTORY** or **DOCUMENT_ROOT**.
For linux I recommend to setup the user/group configuration to match the user you use on your host for development. 
(Including user- and group-ids)

Here an example *docker-compose.yml* file you could use for your project:

```
version: "3"
volumes:
  dbfiles:
services:
  web:
    image: "jensn/webdev-php7:latest"
    extra_hosts:
     - "www.myproject.dock:127.0.0.1"
     - "myproject.dock:127.0.0.1"
    environment:
      APACHE_RUN_USER: 'john'
      APACHE_RUN_GROUP: 'john'
      APACHE_RUN_UID: '1000'
      APACHE_RUN_GID: '1000'
      APACHE_RUN_USER_HOME: '/home/john'
      SERVER_ADMIN: 'webmaster@myproject.dock'
      SERVER_NAME: 'www.myproject.dock'
      SERVER_ALIAS: 'myproject.dock *.myproject.dock'
      DIRECTORY: '/var/www/projects/myproject'
      DOCUMENT_ROOT: '/var/www/projects/myproject/public'
      LOG_DIRECTORY: '/var/www/projects/myproject/logs'
    volumes:
     - "/home/john/project/myproject:/var/www/projects/myproject"
    ports:
     - "80:80"
     - "443:443"
    links:
     - mysql
  mysql:
    image: "mysql:latest"
    volumes:
     - "dbfiles:/var/lib/mysql"
    environment:
      MYSQL_DATABASE: 'myproject'
      MYSQL_USER: 'myproject'
      MYSQL_PASSWORD: 'myprojectsecret'
      MYSQL_RANDOM_ROOT_PASSWORD: 'yes'
    ports:
     - "3306:3306"
```

## Git & Composer checkout

If the you supply a git url, the image will automatically clone the project.
Also it will run a "composer update" for your project if a *composer.json* is present in the root directory.

For this the following environment variables are available
- **GIT_SOURCE** The url to your git repository
- **GIT_DIRECTORY** The target directory for the checkout *(Default: "$DIRECTORY")*

**If your repository is private, make sure a proper ssh key is configured in your "$APACHE_RUN_USER_HOME/.ssh" directory!**
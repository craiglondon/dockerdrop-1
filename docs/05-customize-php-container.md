# DockerDrop, a training site for Docker for Development with Drupal

## Lesson 5:  Customize your PHP container
 
### 1: Evaluate missing PHP extensions needed for Drupal and create a Dockerfile for a PHP container

Let's take a look at the PHP Information that is displayed by our website's index.php file currently.

If you scan down the page you'll notice that the "official" php container is missing some key php extensions that are needed to be able to run a Drupal site:

- A Database extension for MySQL
- an Image Library extension (GD)
- Opcode Cache (opcache)

I would recommend that you also install:
- Mcrypt (an encryption library)
- Iconv extension (Human Language and Character Encoding Support), needed for some mime support, UTF8, latin character support etc.

Some Drupal security extensions will leverage Mcrypt if it's available.

Drush uses compression / decompression libraries for some functions, so we'll install:
- Zip
- Unzip
- Zip PHP extension

Finally, since our MySQL container is separate from the container where PHP is located, you will need a MySQL client application for some of the Drush sql commands, so we'll install:
- MariaDB Client

Well, since you can't shell into a container and add php extensions and have them persist after the container is destroyed, your next best option is to create a custom PHP container, similar to what we did for NginX.

First thing, create the directory `docker/php` in your project root.

Inside that directory create a `Dockerfile`, and add the following:
~~~
FROM php:7.0-fpm

MAINTAINER Lisa Ridley "lhridley@gmail.com"
~~~

We're going to base our Dockerfile on the same container we are using to build our application stack currently.

### 2:  Add code to include the MySQL, GD, Zip, Iconv, Mcrypt, and Opcache php extensions

If you check out the documentation for the Official PHP Docker container, you will see instructions for adding PHP extensions to the base container build.  There are some convenience applications in the official PHP container images that make this process fairly straightforward.

Let's install the dependencies for our extensions, and install the extensions themselves using the convenience applications provided in the official container.  Add the following to your Dockerfile, below the first set of lines:
~~~
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng12-dev \
        unzip \
        zip \
        mariadb-client \
    && docker-php-ext-install -j$(nproc) iconv mcrypt \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install zip \
    && docker-php-ext-install opcache
~~~

If you've ever had to install packages on a Linux server or a virtual machine, these commands may look familiar to you.  The RUN keyword is a Docker command that is used to execute commands available from binaries installed in the base container, using the "shell" application (`/bin/sh`).


### 3:  Add code to include Composer and Drush in our PHP container, and a drush alias file

Well, we are building a container to work with Drupal, so naturally we need Drush installed.  For the container to work with Drupal 8, we also need Composer.  Let's add those two applications to our container.  Add the following lines below the one already added to our `Dockerfile`:

~~~
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php -r "if (hash_file('SHA384', 'composer-setup.php') === 'aa96f26c2b67226a324c27919f1eb05f21c248b987e6195cad9690d5c1ff713d53020a02ac8c217dbf90a7eacc9d141d') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer

RUN php -r "readfile('https://s3.amazonaws.com/files.drush.org/drush.phar');" > drush \
    && chmod +x drush \
    && mv drush /usr/local/bin \
    && drush init -y

RUN mkdir -p /etc/drush/site-aliases
COPY default.aliases.drushrc.php /etc/drush/site-aliases/

~~~

### 4:  Modify the `docker-compose.yml` file to use our custom image definition instead of the "official" image

# Add default drush aliases

Create a file in your `docker/php` directory called `default.aliases.drushrc.php`, and add the following to it:

~~~
<?php
$aliases[isset($_SERVER['PHP_SITE_NAME']) ? $_SERVER['PHP_SITE_NAME'] : 'dev'] = [
  'root' => '/var/www/html/' . (isset($_SERVER['PHP_DOCROOT']) ? $_SERVER['PHP_DOCROOT'] : ''),
  'uri' => isset($_SERVER['PHP_HOST_NAME']) ? $_SERVER['PHP_HOST_NAME'] : 'localhost:8000',
];
~~~

### 4:  Add a php.ini base file, and an entrypoint shell script

Create a base php.ini file with some commonly adjusted settings in it, plus some we will need in our next lesson.  Create a file named `php.ini` in `docker/php` and include the following:

~~~
; php.ini
[php]
memory_limit = 192M
allow_url_include = On
;sendmail_path =
;post_max_size =
;upload_max_filesize =
;max_execution_time =

[opcache]
opcache.enable = On
opcache.validate_timestamps = 1
opcache.revalidate_freq = 2
opcache.max_accelerated_files = 20000
opcache.memory_consumption = 64
opcache.interned_strings_buffer = 16
opcache.fast_shutdown = 1
~~~

Now, we will add an Entrypoint script for our container.  Create a file called `docker-entrypoint.sh` in `docker/php` and include the following:

~~~
#!/bin/bash

set -eo pipefail

if [ -n "$PHP_MEMORY_LIMIT" ]; then
     sed -i 's@^memory_limit.*@'"memory_limit = ${PHP_MEMORY_LIMIT}"'@' /usr/local/etc/php/conf.d/php.ini
fi

if [ -n "$PHP_MAX_EXECUTION_TIME" ]; then
     sed -i 's@^;max_execution_time.*@'"max_execution_time = ${PHP_MAX_EXECUTION_TIME}"'@' /usr/local/etc/php/conf.d/php.ini
fi

if [ -n "$PHP_POST_MAX_SIZE" ]; then
     sed -i 's@^;post_max_size.*@'"post_max_size = ${PHP_POST_MAX_SIZE}"'@' /usr/local/etc/php/conf.d/php.ini
fi

if [ -n "$PHP_UPLOAD_MAX_FILESIZE" ]; then
     sed -i 's@^;upload_max_filesize.*@'"upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}"'@' /usr/local/etc/php/conf.d/php.ini
fi

exec php-fpm
~~~

Add these two files to our Dockerfile by inserting the following lines:

~~~
# Add php.ini base file
COPY php.ini /usr/local/etc/php/conf.d/php.ini

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT /usr/local/bin/docker-entrypoint.sh
~~~

### 5:  Modify the `docker-compose.yml` file to use our custom image definition instead of the "official" image

Open `docker-compose.yml`, and replace the following:

~~~
  php:
    image: php:7.0-fpm
    expose:
      - 9000
    volumes:
      - ./web:/var/www/html/web
~~~

with:

~~~
  php:
    build: ./docker/php/
    expose:
      - 9000
    volumes:
      - .:/var/www/html/web
    depends_on:
      - db
    environment:
      PHP_SITE_NAME: dev
      PHP_HOST_NAME: localhost:8000  #Match the host port on NginX
      PHP_DOCROOT: www/web
      PHP_MEMORY_LIMIT: 256M
      PHP_MAX_EXECUTION_TIME: 60
      # if you use PHP_POST_MAX_SIZE, make sure you set the NGINX_MAX_BODY_SIZE
      # to the same, but use a lowercase "m" instead of an uppercase "M"
      PHP_POST_MAX_SIZE: 16M
      PHP_UPLOAD_MAX_FILESIZE: 16M
~~~

and save it.

Now, execute `docker-compose up -d --build`, and let's see what happens.

After your containers are up and running, navigate to `localhost:8000` and take a look at the information displayed.  You will now see that PHP has additional extensions installed for zip, iconv, mcrypt, pdo-mysql and gd, which were not installed previously.

Congratulations!  You have a complete Docker stack that is configured to support Drupal development.

Your `docker-compose.yml` file should look similar to:

~~~
version: '2'
services:
  web:
    build: ./docker/nginx/
    ports:
      - "8000:80"
    volumes_from:
      - php
    depends_on:
      - php

  php:
    build: ./docker/php/
    expose:
      - 9000
    volumes:
      - .:/var/www/html
    depends_on:
      - db
    environment:
      PHP_SITE_NAME: dev
      PHP_HOST_NAME: localhost:8000  #Match the host port on NginX
      PHP_DOCROOT: www/web
      PHP_MEMORY_LIMIT: 256M
      PHP_MAX_EXECUTION_TIME: 60
      # if you use PHP_POST_MAX_SIZE, make sure you set the NGINX_MAX_BODY_SIZE
      # to the same, but use a lowercase "m" instead of an uppercase "M"
      PHP_POST_MAX_SIZE: 16M
      PHP_UPLOAD_MAX_FILESIZE: 16M

  db:
    image: mariadb:10.1.19
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: drupal
      MYSQL_USER: drupal
      MYSQL_PASSWORD: drupal
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci # The simple way to override the mariadb config.
    volumes:
      - mysql-data:/var/lib/mysql
      - ./db:/docker-entrypoint-initdb.d # Place init .sql file(s) here.

volumes:
  mysql-data:
    driver: local
~~~

And your php `Dockerfile should look similar to`:

~~~
FROM php:7.0-fpm

MAINTAINER Lisa Ridley "lhridley@gmail.com"

RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng12-dev \
        unzip \
        zip \
        mariadb-client \
    && docker-php-ext-install -j$(nproc) iconv mcrypt \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install zip

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php -r "if (hash_file('SHA384', 'composer-setup.php') === 'aa96f26c2b67226a324c27919f1eb05f21c248b987e6195cad9690d5c1ff713d53020a02ac8c217dbf90a7eacc9d141d') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer

RUN php -r "readfile('https://s3.amazonaws.com/files.drush.org/drush.phar');" > drush \
    && chmod +x drush \
    && mv drush /usr/local/bin \
    && drush init -y


# Add default drush aliases
RUN mkdir -p /etc/drush/site-aliases
COPY default.aliases.drushrc.php /etc/drush/site-aliases/

# Add php.ini base file
COPY php.ini /usr/local/etc/php/conf.d/php.ini

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT /usr/local/bin/docker-entrypoint.sh
~~~

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />The instructional materials, which includes any materials in this repository included in markdown (.md) and/or text (.txt) files, are licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.

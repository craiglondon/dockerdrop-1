# DockerDrop, a training site for Docker for Development with Drupal

## Lesson 5:  Customize your PHP container
 
### 1: Evaluate missing PHP extensions needed for Drupal and create a Dockerfile for a PHP container

Let's take a look at the PHP Information that is displayed by our website's index.php file currently.

If you scan down the page you'll notice that the "official" php container is missing some key php extensions that are needed to be able to run a Drupal site:

- A Database extension for MySQL
- an Image Library extension (GD)

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

### 2:  Add code to include the MySQL, GD and Mcrypt php extensions

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
    && docker-php-ext-install zip
~~~

If you've ever had to install packages on a Linux server or a virtual machine, these commands may look familiar to you.  The RUN keyword is a Docker command that is used to execute commands available from binaries installed in the base container, using the "shell" application (`/bin/sh`).

### 3:  Add code to include Composer and Drush in our PHP container

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
~~~

### 4:  Modify the `docker-compose.yml` file to use our custom image definition instead of the "official" image

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
      - ./web:/var/www/html/web
    depends_on:
      - db
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
      - ./web:/var/www/html/web
    depends_on:
      - db

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
~~~

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />The instructional materials, which includes any materials in this repository included in markdown (.md) and/or text (.txt) files, are licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.

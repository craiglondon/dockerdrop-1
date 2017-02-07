# DockerDrop, a training site for Docker for Development with Drupal

## Lesson 6:  Add MailHog and Selenium containers for development and testing 
 
### 1: Add Mailhog to your stack

Mailhog is an email testing tool for developers that allows you to fully test mail functions for a website without having a mail server installed.  Mailhog can act as a SMTP proxy, and will capture outgoing email from an application configured to use it.

Conveniently, the maintainers of Mailhog have provided us with....Docker containers!

To add Mailhog to your application stack, open your `docker-compose.yml` file and insert the following under the `services` key:

~~~
  mailhog:
    image: mailhog/mailhog:latest
    ports:
      - "8002:8025"
~~~

This will add a MailHog container to your application stack, and will make the MailHog GUI available on port 8002.

### 2: Configure PHP to route outgoing mail to our MailHog container

By default, PHP uses sendmail to send out email from a web service; however, we don't have sendmail installed in our PHP containers.  The MailHog community has written a sendmail replacement that is specifically designed to route mail to a MailHog instance.

To install this application in our PHP container, edit the `docker/php/Dockerfile` and add the following code, right after the block of code that adds the Drush Alias file:

~~~
# Install Mailhog Sendmail support:
RUN apt-get update -qq && apt-get install -yq git golang-go \
    && mkdir -p /opt/go \
    && export GOPATH=/opt/go \
    && go get github.com/mailhog/mhsendmail
~~~

Now, we need to configure our PHP instance to use this application to handle outgoing mail, and tell PHP the location of the MailHog application.  Edit `docker/php/php.ini` and add the following lines to the end of the file:

~~~
[mailhog]
; Mailhog php.ini settings.
sendmail_path = "/opt/go/bin/mhsendmail --smtp-addr=mailhog:1025"
~~~

### 3: Add a Selenium container to our stack for testing purposes

If you are in the practice of writing user acceptance and unit tests for your applications, and you like to test your applications as you write them, you can implement a testing process using Selenium to execute your user acceptance tests.

As you are probably aware, Drupal has a plugin for the Symfony2 Behat module that enhances the available user acceptance testing steps that Behat provides for testing web applications.  While we won't go through the hows and whys of writing user acceptance tests as part of this training, we will implement a basic user acceptance test suite to execute enough tests to have a workable model for building our application on Travis-CI, and we'll use Selenium to execute those tests.

If you've ever installed Selenium for testing purposes you're probably aware that it is a cumbersome and time consuming application to install and configure.  The Selenium community has been kind enough to provide us with pre-built Docker container images that we can leverage for use in our projects for executing automated tests driven by Selenium.

To add a Selenium container to our stack, edit the `docker-compose.yml` file and add the following beneath the `services` key:

~~~
  selenium:
    image: selenium/standalone-firefox:2.53.0
~~~

That's it!  No length builds, no configuration, other than to configure Behat to use the Selenium instance in our container to execute tests.

### 4: Recap

Our PHP image's Dockerfile now looks as follows:

~~~
FROM php:7.0-fpm

MAINTAINER Lisa Ridley "lhridley@gmail.com"

RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng12-dev \
        vim \
        unzip \
        zip \
        mariadb-client \
    && docker-php-ext-install -j$(nproc) iconv mcrypt \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install zip \
    && docker-php-ext-install opcache

#Add Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php -r "if (hash_file('SHA384', 'composer-setup.php') === 'aa96f26c2b67226a324c27919f1eb05f21c248b987e6195cad9690d5c1ff713d53020a02ac8c217dbf90a7eacc9d141d') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer

# Add Drush Globally
RUN php -r "readfile('https://s3.amazonaws.com/files.drush.org/drush.phar');" > drush \
    && chmod +x drush \
    && mv drush /usr/local/bin \
    && drush init -y

# Add default drush aliases
RUN mkdir -p /etc/drush/site-aliases
COPY default.aliases.drushrc.php /etc/drush/site-aliases/

# Install Mailhog Sendmail support:
RUN apt-get update -qq && apt-get install -yq git golang-go \
    && mkdir -p /opt/go \
    && export GOPATH=/opt/go \
    && go get github.com/mailhog/mhsendmail

# Add php.ini base file
COPY php.ini /usr/local/etc/php/conf.d/php.ini

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT /usr/local/bin/docker-entrypoint.sh
~~~

Our `php.ini` file contains the following:

~~~
; php.ini
[php]
memory_limit = 192M
allow_url_include = On
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

[mailhog]
; Mailhog php.ini settings.
sendmail_path = "/opt/go/bin/mhsendmail --smtp-addr=mailhog:1025"
~~~

And finally, our `docker-compose.yml` file looks like this:

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
    environment:
      NGINX_DOCROOT: www/web
      NGINX_SERVER_NAME: localhost
      # Set to the same as the PHP_POST_MAX_SIZE, but use lowercase "m"
      NGINX_MAX_BODY_SIZE: 16m

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
    image: mysql:5.6.34
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: drupal
      MYSQL_USER: drupal
      MYSQL_PASSWORD: drupal
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci # The simple way to override the mariadb config.
    volumes:
      - mysql-data:/var/lib/mysql
      - ./data:/docker-entrypoint-initdb.d # Place init .sql file(s) here.

  mailhog:
    image: mailhog/mailhog:latest
    expose:
     - "1025"
    ports:
      - "8002:8025"

  selenium:
    image: selenium/standalone-firefox:2.53.0

volumes:
  mysql-data:
    driver: local

~~~

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />The instructional materials, which includes any materials in this repository included in markdown (.md) and/or text (.txt) files, are licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.

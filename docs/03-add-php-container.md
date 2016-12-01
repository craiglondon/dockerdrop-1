# DockerDrop, a training site for Docker for Development with Drupal

## Lesson 3:  Add PHP to our stack, and build a custom NginX container
 
### 1: Add `web` folder with `index.php` to our project

Create a directory called `web` at the root of our project.  Inside that directory, create a filed called `index.php` with the following contents:

~~~
<?php
phpinfo();
~~~

### 2: Add the php-fpm container configuration to `docker-compose.yml`

Open `docker-compose.yml` in your favorite editor and add the following lines for the PHP service under the `service` key:

~~~
  php:
    image: php:7.0.13-fpm
    expose:
      - 9000
    volumes:
      - ./web:/var/www/html/web

~~~

Note that we are pinning our PHP container to version `7.0.13-fpm`.

The PHP images don't expose port 9000 by default, so we specify it ourselves in our configuration settings.

The difference between `expose` and `ports` is that `expose` lets you expose some ports to the other containers only, and `port` lets you make them accessible to the host machine.

We have also added a volumes key to our PHP container configuration, which we are using to specify data volumes for the PHP container.  A data volume is a specially-designated directory within one or more containers that bypasses Docker's Union File System, which is the Docker file system that operates by creating layers. 

Data volumes can be structured so that they are shared among containers, as well as configured to share directories with the host machine in certain circumstances, which is what we are doing here.  Similar to ports, shared volumes can be mapped in the following format:  `<host machine directory>:<container directory>`.

What we're saying here is that the current directory (designated with . ) must be mounted inside the container as its /var/www/html directory. To simplify, it means that the content of the current directory on our host machine will be in sync with the containers. It also means that this content will be persistent even if we destroy the container.
More on that later.

### 3. Add a custom nginx config file to your repository
Now that we're adding another container to our stack, our two containers need to "talk" to each other.  We also need to change the default configuration of NginX so that it loads a config file better suited to handle all of the configuration settings needed for a Drupal application.

Create a file in the `docker/nginx` directory called `default.conf`, and put the following in it:

~~~
# Let's redirect https requests to http; you'll want to modify this if you
# need to test over https

server {
    listen 443;
    listen [::]:443;

    return 302 http://$server_name$request_uri;
}

server {
    server_name SERVER_NAME;

    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    access_log off;
    error_log  /var/log/nginx/error.log error;

    sendfile off;


    client_max_body_size MAX_BODY_SIZE;

    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    # Allow "Well-Known URIs" as per RFC 5785
    location ~* ^/.well-known/ {
        allow all;
    }

    # Block access to "hidden" files and directories whose names begin with a
    # period. This includes directories used by version control systems such
    # as Subversion or Git to store control files.
    location ~ (^|/)\. {
        return 403;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }

    # Don't allow direct access to PHP files in the vendor directory.
    location ~ /vendor/.*\.php$ {
        deny all;
        return 404;
    }

    # In Drupal 8, we must also match new paths where the '.php' appears in
    # the middle, such as update.php/selection. The rule we use is strict,
    # and only allows this pattern with the update.php front controller.
    # This allows legacy path aliases in the form of
    # blog/index.php/legacy-path to continue to route to Drupal nodes. If
    # you do not have any paths like that, then you might prefer to use a
    # laxer rule, such as:
    #   location ~ \.php(/|$) {
    # The laxer rule will continue to work if Drupal uses this new URL
    # pattern with front controllers other than update.php in a future
    # release.
    location ~ '\.php$|^/update.php' {
        fastcgi_split_path_info ^(.+?\.php)(|/.*)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_intercept_errors on;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    # Fighting with Styles? This little gem is amazing.
    # location ~ ^/sites/.*/files/imagecache/ { # For Drupal <= 6
    location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
        try_files $uri @rewrite;
    }

    # Handle private files through Drupal.
    location ~ ^/system/files/ { # For Drupal >= 7
        try_files $uri /index.php?$query_string;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }

    location ~ /\.ht {
        deny all;
    }
}

~~~

Save this file.

### 4. Create a custom NginX container, and modify your NginX container to load the newly added config file

By default, the "official" NginX container uses the default configuration file that get installed when NginX is installed.  We can, however, create our own container that loads the configuration file we just created.

Create a file called `Dockerfile` in the `docker/nginx` directory, and put the following in it:

~~~
FROM nginx:1.10.2

MAINTAINER Lisa Ridley "lhridley@gmail.com"

COPY ./default.conf /etc/nginx/conf.d/default.conf

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT /usr/local/bin/docker-entrypoint.sh

~~~

What we are doing here is creating a custom Docker container that is based on the nginx:1.10.2 container.  We are tagging ourselves as the maintainer, and we specify that we want to copy our `default.conf` file over the one supplied by NginX.

We are also adding a custom entrypoint script, which we'll create in a minute.

That was easy enough.

Now, to use the container we just defined, we need to modify our `docker-compose.yml` file, so open it in your editor and replace this line:

~~~
    image: nginx:1.10.2
~~~

with this:
~~~
    build: ./docker/nginx/
~~~

We've basically just instructed docker-compose to build a web container from the Dockerfile we defined when we start our stack.

Now, let's add some environment variables for our NginX container, the values from which are used in our entrypoint script.  Add the following to your `docker-compose.yml` file under the `web` service tag:

~~~
    environment:
      NGINX_DOCROOT: www/web
      NGINX_SERVER_NAME: localhost
      # Set to the same as the PHP_POST_MAX_SIZE, but use lowercase "m"
      NGINX_MAX_BODY_SIZE: 16m

~~~

Now, we need to share the volume from our PHP container with our NginX container so that it knows what to serve up when it starts.  Modify your web service in your docker-compose file to read as follows:

~~~
  web:
    build: ./docker/nginx/
    ports:
      - "8000:80"
    volumes_from:
      - php
    depends_on:
      - php

~~~

We're basically telling docker-compose that our web container is sharing the volumes that the PHP container has associated with it, and that our web container is dependent upon our PHP container.  What docker-compose will do is start the php container first before it starts the web container, so that the volumes shared from the PHP container are available to the web container when it starts.

### 5. Reload all containers in your stack

Issue the following command:

~~~~
docker-compose down
docker-compose up -d
~~~~

...and navigate to `localhost:8000`.  You should see information about your PHP web installation, as follows:

![PHPInfo](https://github.com/lhridley/dockerdrop/raw/03-add-php-container/docs/phpinfo.png "PHPInfo")


At this point your docker-compose.yml file should look as follows:

~~~~
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
      NGINX_DOCROOT: web
      NGINX_SERVER_NAME: localhost
      # Set to the same as the PHP_POST_MAX_SIZE, but use lowercase "m"
      NGINX_MAX_BODY_SIZE: 16m

  php:
    image: php:7.0-fpm
    expose:
      - 9000
    volumes:
      - ./web:/var/www/html/web
~~~~

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />The instructional materials, which includes any materials in this repository included in markdown (.md) and/or text (.txt) files, are licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.

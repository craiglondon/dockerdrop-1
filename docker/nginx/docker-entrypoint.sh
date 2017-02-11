#!/bin/bash

set -eo pipefail

# Configure docroot.
if [ -n "$NGINX_DOCROOT" ]; then
    sed -i 's@root /var/www/html;@'"root /var/www/html/${NGINX_DOCROOT};"'@' /etc/nginx/conf.d/*.conf
fi

# Ensure max_body_size is defined, and configure client_max_body_size
if [ -z "$NGINX_MAX_BODY_SIZE" ]; then
    NGINX_MAX_BODY_SIZE=8m
fi
sed -i 's/MAX_BODY_SIZE/'"${NGINX_MAX_BODY_SIZE}"'/' /etc/nginx/conf.d/*.conf

# Ensure server name defined, and set the server_name
if [ -z "$NGINX_SERVER_NAME" ]; then
    NGINX_SERVER_NAME=localhost
fi
sed -i 's/SERVER_NAME/'"${NGINX_SERVER_NAME}"'/' /etc/nginx/conf.d/*.conf

exec "$@"

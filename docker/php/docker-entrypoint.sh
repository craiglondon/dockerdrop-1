#!/bin/bash

set -eo pipefail

if [ -n "$PHP_SENDMAIL_PATH" ]; then
     sed -i 's@^;sendmail_path.*@'"sendmail_path = ${PHP_SENDMAIL_PATH}"'@' /usr/local/etc/php/conf.d/php.ini
fi

if [ -n "$PHP_MEMORY_LIMIT" ]; then
     sed -i 's@^memory_limit.*@'"memory_limit = ${PHP_MEMORY_LIMIT}"'@' /usr/local/etc/php/conf.d/php.ini
fi

if [ -n "$PHP_POST_MAX_SIZE" ]; then
     sed -i 's@^;post_max_size.*@'"post_max_size = ${PHP_POST_MAX_SIZE}"'@' /usr/local/etc/php/conf.d/php.ini
fi

if [ -n "$PHP_UPLOAD_MAX_FILESIZE" ]; then
     sed -i 's@^;upload_max_filesize.*@'"post_max_size = ${PHP_UPLOAD_MAX_FILESIZE}"'@' /usr/local/etc/php/conf.d/php.ini
fi

exec php-fpm

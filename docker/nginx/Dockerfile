FROM nginx:1.10.2

MAINTAINER Lisa Ridley "lhridley@gmail.com"

COPY ./default.conf /etc/nginx/conf.d/default.conf

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT /usr/local/bin/docker-entrypoint.sh

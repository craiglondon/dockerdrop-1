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


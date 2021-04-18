FROM ubi8/ubi

MAINTAINER Jakub Micanek jakub_micanek@centrum.cz

LABEL description="My test container dockerfile"

# declare environment variable for use elsewhere
ENV PORT 8080

# Run multiple yum commands in a single RUN directive to reduce number of image layers
RUN yum install -y httpd && \
    yum clean all

RUN sed -ri -e "/^Listen 80/c\Listen ${PORT}" /etc/httpd/conf/httpd.conf && \
    chown -R apache:apache /etc/httpd/logs/ && \
    chown -R apache:apache /run/httpd/

USER apache

# Let reader know which port is exposed by the container
EXPOSE ${PORT}

COPY ./src/ /var/www/html/

CMD ["httpd","-D","FOREGROUND"]

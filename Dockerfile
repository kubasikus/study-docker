FROM ubi8/ubi

MAINTAINER Jakub Micanek jakub_micanek@centrum.cz

LABEL description="My test container dockerfile"

# Run multiple yum commands in a single RUN directive to reduce number of image layers
RUN yum install -y httpd && \
    yum clean all

RUN echo "HELLO from Dockerfile" > /usr/share/httpd/noindex/index.html

# Let reader know which port is exposed by the container
EXPOSE 80

ENTRYPOINT ["httpd","-D","FOREGROUND"]

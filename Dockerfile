FROM --platform=$BUILDPLATFORM golang:latest AS build
ENV DOCKER_GEN_VERSION 0.7.4
RUN git clone --depth 1 -q https://github.com/ddollar/forego.git /usr/src/forego
RUN git clone --depth 1 -q -b ${DOCKER_GEN_VERSION} https://github.com/jwilder/docker-gen.git /usr/src/docker-gen
WORKDIR /usr/src/forego
RUN go get -d ./...
RUN make
WORKDIR /usr/src/docker-gen
RUN go get -d ./...
RUN make

FROM --platform=$BUILDPLATFORM nginx:1.19.3
LABEL author="Jason Wilder <mail@jasonwilder.com>"
LABEL maintainer="Hugo Haldi <hugo.haldi@gmail.com>"

# Install wget and install/updates certificates
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*


# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
 && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf

# Install Forego
COPY --from=build /usr/src/forego/forego /usr/local/bin/

COPY --from=build /usr/src/docker-gen/docker-gen /usr/local/bin/

COPY network_internal.conf /etc/nginx/

COPY . /app/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]

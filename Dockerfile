FROM kubedb/postgres:10.2-v2

ENV TIMESCALEDB_VERSION 1.3.0

COPY pg_prometheus.control Makefile /build/pg_prometheus/
COPY src/*.c src/*.h /build/pg_prometheus/src/
COPY sql/prometheus.sql /build/pg_prometheus/sql/

RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
    ca-certificates \
    openssl \
    libressl \
    libressl-dev \
    tar \
    && mkdir -p /build/timescaledb \
    && wget -O /timescaledb.tar.gz https://github.com/timescale/timescaledb/archive/$TIMESCALEDB_VERSION.tar.gz \
    && tar -C /build/timescaledb --strip-components 1 -zxf /timescaledb.tar.gz \
    && rm -f /timescaledb.tar.gz \
    \
    && apk add --no-cache --virtual .build-deps \
    coreutils \
    dpkg-dev dpkg \
    gcc \
    libc-dev \
    make \
    cmake \
    util-linux-dev \
    \
    && cd /build/timescaledb \
    && ./bootstrap \
    && cd build && make install \
    && make -C /build/pg_prometheus install \
    && cd ~ \
    \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build

RUN sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,pg_prometheus,\2'/;s/,'/'/" /scripts/primary/postgresql.conf
RUN cat /scripts/primary/postgresql.conf

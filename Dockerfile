# daemon runs in the background
# run something like tail /var/log/weaknesscoind/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/weaknesscoind:/var/lib/weaknesscoind -v $(pwd)/wallet:/home/weaknesscoin --rm -ti weaknesscoin:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG TURTLECOIN_BRANCH=master
ENV TURTLECOIN_BRANCH=${TURTLECOIN_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/weaknesscoin/weaknesscoin.git /src/weaknesscoin && \
    cd /src/weaknesscoin && \
    git checkout $TURTLECOIN_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/WeaknessCoind /usr/local/bin/WeaknessCoind && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/WeaknessCoind && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/weaknesscoin && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the weaknesscoind service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/weaknesscoind weaknesscoind && \
    useradd -s /bin/bash -m -d /home/weaknesscoin weaknesscoin && \
    mkdir -p /etc/services.d/weaknesscoind/log && \
    mkdir -p /var/log/weaknesscoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/weaknesscoind/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/weaknesscoind/run && \
    echo "cd /var/lib/weaknesscoind" >> /etc/services.d/weaknesscoind/run && \
    echo "export HOME /var/lib/weaknesscoind" >> /etc/services.d/weaknesscoind/run && \
    echo "s6-setuidgid weaknesscoind /usr/local/bin/WeaknessCoind" >> /etc/services.d/weaknesscoind/run && \
    chmod +x /etc/services.d/weaknesscoind/run && \
    chown nobody:nogroup /var/log/weaknesscoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/weaknesscoind/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/weaknesscoind/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/weaknesscoind" >> /etc/services.d/weaknesscoind/log/run && \
    chmod +x /etc/services.d/weaknesscoind/log/run && \
    echo "/var/lib/weaknesscoind true weaknesscoind 0644 0755" > /etc/fix-attrs.d/weaknesscoind-home && \
    echo "/home/weaknesscoin true weaknesscoin 0644 0755" > /etc/fix-attrs.d/weaknesscoin-home && \
    echo "/var/log/weaknesscoind true nobody 0644 0755" > /etc/fix-attrs.d/weaknesscoind-logs

VOLUME ["/var/lib/weaknesscoind", "/home/weaknesscoin","/var/log/weaknesscoind"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/weaknesscoin export HOME /home/weaknesscoin s6-setuidgid weaknesscoin /bin/bash"]

FROM alpine:latest

RUN apk add --no-cache \
      ca-certificates \
      wget \
      curl \
      gcc \
      libc-dev \
      make \
      libressl-dev \
      git \
      coreutils \
      gnupg \
      unzip \
      moreutils \
      linux-headers \
      openssl \
      lua5.4-dev \
      sudo \
      bash \
    && rm -rf /tmp/* \
    && mkdir /usr/local/include \
    && export LUA_INCDIR=/usr/include/lua5.4  \
    && cd /tmp  \ 
    && wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz \
    && tar zxpf luarocks-3.11.1.tar.gz \
    && cd luarocks-3.11.1  \
    && ./configure --with-lua-include=/usr/include/lua5.4 \
    && make \
    && sudo make install \
    && cd ..  \
    && rm -rf /tmp/* \
    && sudo luarocks --version \
    && sudo luarocks install luasocket \
    && sudo luarocks install luasec \
    && sudo luarocks install luafilesystem \  
    && sudo luarocks install luasystem \  
    && sudo luarocks install timerwheel \
    && sudo luarocks install copas \
    && sudo luarocks install luamqttt \
    && sudo luarocks install mobdebug \
    && sudo luarocks install lua-websockets-bit32 \
    && sudo luarocks install lua-json \
    && sudo luarocks install bit32 \
    && sudo luarocks install argparse \
    && sudo luarocks install datafile \
    && sudo luarocks install hc3emu \
    && apk del gcc make curl wget libc-dev moreutils coreutils \
    && cp /usr/bin/lua5.4 /usr/bin/lua

#ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib"

WORKDIR /develop/
RUN mkdir db
#EXPOSE 8080/tcp 8888/tcp

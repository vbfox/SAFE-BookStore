FROM microsoft/aspnetcore-build:2.0.5-2.1.4-stretch AS builder

# Install Mono
ENV MONO_VERSION 5.4.1.6
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
RUN echo "deb http://download.mono-project.com/repo/debian jessie/snapshots/$MONO_VERSION main" > /etc/apt/sources.list.d/mono-official.list \
  && apt-get update \
  && apt-get install -y mono-runtime binutils curl mono-devel ca-certificates-mono fsharp mono-vbnc nuget referenceassemblies-pcl \
  && rm -rf /var/lib/apt/lists/* /tmp/*

# Install Yarn
ENV YARN_VERSION 1.3.2
RUN set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
  done \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt/yarn \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/yarn --strip-components=1 \
  && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

WORKDIR /build

# Package lock files are copied independently and their respective package
# manager are executed after.
#
# This is voluntary as docker will cache images and only re-create them if
# the already-copied files have changed, by doing that as long as no package
# is installed or updated we keep the cached container and don't need to
# re-download.

# Initialize node_modules
COPY yarn.lock package.json ./
RUN yarn install
RUN npm install phantomjs-prebuilt

# Initialize paket packages
COPY paket.dependencies paket.lock ./
COPY .paket .paket
RUN mono .paket/paket.exe restore

# Copy everything else and run the build
COPY . ./
RUN ./build.sh All

FROM microsoft/aspnetcore
WORKDIR /app
COPY --from=builder /build/deploy ./
EXPOSE 8085
ENTRYPOINT ["dotnet", "Server.dll"]

FROM heroku/heroku:22-build as builder

ENV HOME=/app \
    HEROKU_HOME=/heroku \
    HEROKU_BUILDPACK_VERSION=22 \
    GO_VERSION=1.21.5 \
    NODE_VERSION=18.9.0 \
    YARN_VERSION=4.0.2

COPY . /app
WORKDIR /app
# Setup buildpack
RUN mkdir -p /tmp/buildpack/heroku/nodejs
RUN curl https://buildpack-registry.s3.amazonaws.com/buildpacks/heroku/nodejs.tgz | tar xz -C /tmp/buildpack/heroku/nodejs

RUN mkdir -p /tmp/buildpack/heroku/go /tmp/build_cache /tmp/env
RUN curl https://buildpack-registry.s3.amazonaws.com/buildpacks/heroku/go.tgz | tar xz -C /tmp/buildpack/heroku/go

RUN curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(go env GOPATH)/bin v1.24.0

RUN STACK=heroku-20 /tmp/buildpack/heroku/go/bin/compile /app /tmp/build_cache /tmp/env

RUN npm install --g --no-progress yarn && corepack enable \
    && npm install --g --no-progress @yarnpkg/cli@4.0.2 \
    && yarn set version 4.0.2 --yarn-path
RUN yarn install

RUN buffalo build --static -o /bin/aquila-server

FROM heroku/heroku:22

COPY --from=builder /bin/aquila-server /app/bin/aquila-server
ENV HOME /app
WORKDIR /app
RUN useradd -m heroku
USER heroku
CMD /app/bin/aquila-server
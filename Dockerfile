FROM heroku/heroku:22-build as builder

ENV HEROKU_HOME=/heroku
# Prepare nodejs
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash 
RUN apt-get update && apt-get install nodejs
RUN apt-get install -y -q build-essential sqlite3 libsqlite3-dev postgresql libpq-dev

RUN wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz \
    && tar -xf go1.21.0.linux-amd64.tar.gz \
    && mv go /usr/local \
    && export GOROOT=/usr/local/go \
    && export GOPATH=$HOME/go \
    && export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
RUN curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(go env GOPATH)/bin v1.24.0

WORKDIR /usr/bin
RUN ln -s /usr/local/go/bin/go
RUN go install -tags sqlite github.com/gobuffalo/cli/cmd/buffalo@v0.18.14
RUN go install github.com/gobuffalo/buffalo-pop/v3@latest
RUN ln -s /root/go/bin/buffalo

RUN npm install --g --no-progress yarn && corepack enable \
    && npm install --g --no-progress @yarnpkg/cli@4.0.2 \
    && yarn set version 4.0.2 --yarn-path

# Build App
WORKDIR /app
ADD package.json .
ADD yarn.lock .yarnrc.yml ./
RUN yarn install
COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download
ADD . .
RUN yarn install
RUN buffalo build --static -o /bin/aquila_server

FROM heroku/heroku:22
COPY --from=builder /bin/aquila_server /app/bin/aquila_server
ENV HOME /app
WORKDIR /app
RUN useradd -m heroku
USER heroku
CMD /app/bin/aquila_server


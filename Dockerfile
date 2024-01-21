FROM heroku/heroku:22-build as builder
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash 
RUN apt-get update && apt-get install nodejs
RUN apt-get install -y -q build-essential sqlite3 libsqlite3-dev postgresql libpq-dev vim wget
RUN wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
RUN tar -xf go1.21.0.linux-amd64.tar.gz
RUN mv go /usr/local
RUN export GOROOT=/usr/local/go
RUN export GOPATH=$HOME/go
RUN export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
WORKDIR /usr/bin/
RUN ln -s /usr/local/go/bin/go
RUN go install -tags sqlite github.com/gobuffalo/cli/cmd/buffalo@latest
RUN go install github.com/gobuffalo/buffalo-pop/v3@latest
RUN ln -s /root/go/bin/buffalo

RUN npm install --g --no-progress yarn && corepack enable \
    && npm install --g --no-progress @yarnpkg/cli@4.0.2 \
    && yarn set version 4.0.2 --yarn-path
##    RUN corepack enable \ 
##    && npm install -g @yarnpkg/cli@4.0.2 \
##    && yarn set version 4.0.2 --yarn-path \
##    && yarn install
RUN curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(go env GOPATH)/bin v1.24.0

RUN mkdir /usr/src/aquila-server
WORKDIR /usr/src/aquila-server
ADD package.json .
ADD yarn.lock .yarnrc.yml ./
RUN yarn install
COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download
ADD . .
RUN buffalo build --static -o /bin/aquila-server

FROM heroku/heroku:22
ENV GO_ENV=production
ENV ADDR=0.0.0.0
EXPOSE 3000

RUN apt-get update \
    && apt-get install -y -q postgresql postgresql-contrib libpq-dev\
    && rm -rf /var/lib/apt/lists/* \
    && service postgresql start && \
    su -c "psql -c \"ALTER USER postgres  WITH PASSWORD 'postgres';\"" - postgres

WORKDIR /usr/bin/
ADD database.yml .
COPY --from=builder /bin/aquila-server .
#CMD /bin/aquila-server migrate; /bin/aquila-server
CMD exec /bin/aquila-server
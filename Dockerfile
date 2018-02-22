ARG RUNC_VERSION="b50fa98d9e5ec3ff58028c46767129607067f961"
FROM golang:alpine as gobuild-base
RUN apk add --no-cache git make

FROM gobuild-base AS myapp
WORKDIR /go/src/github.com/justintout/go-template
COPY . .
RUN make static && mv go-template /usr/bin/go-template

FROM gobuild-base AS runc
RUN apk add --no-cache bash g++ libseccomp-dev linux-headers
RUN git clone https://github.com/opencontainers/runc.git "$GOPATH/src/github.com/opencontainers/runc" \ 
    && cd "$GOPATH/src/github.com/opencontainers/runc" \
    && git checkout -q "$RUNC_VERSION" \
    && make static BUILDTAGS="seccomp" EXTRA_FLAGS="-buildmode pie" EXTRA_LDFLAGS="-extldflags \\\"-fno-PIC -static\\\"" \
    && mv runc /usr/bin/runc

FROM alpine
LABEL AUTHOR Justin Tout <justin.tout@case.edu>

RUN apk add --no-cache fuse git
COPY --from=myapp /usr/bin/go-template /usr/bin/go-template
COPY --from=runc /usr/bin/runc /usr/bin/runc
ENTRYPOINT [ "go-template" ]
CMD [ ""]

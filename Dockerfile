FROM betterweb/hugo:latest

VOLUME ["/public"]
COPY . /build
WORKDIR /build

ENTRYPOINT ["/bin/bash", "-lc"]
CMD "while true; sleep 5; done"

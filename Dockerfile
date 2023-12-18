FROM betterweb/hugo:extended-0.121.1-21-1.21.5

VOLUME ["/public"]
COPY . /build
WORKDIR /build

ENTRYPOINT ["/bin/bash", "-lc"]
CMD "while true; sleep 5; done"

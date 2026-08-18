FROM rust:latest AS build

COPY . /usr/src/folder-reader

WORKDIR /usr/src/folder-reader

RUN cargo build --release

RUN cp /usr/src/folder-reader/target/release/folder-reader /usr/local/bin/folder-reader

CMD ["/usr/local/bin/folder-reader"]

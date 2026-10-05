FROM rust:latest AS build

WORKDIR /usr/src/hello-world

COPY . .

RUN cargo build --release

RUN cp /usr/src/hello-world/target/release/hello-world /usr/local/bin/hello-world

CMD ["/usr/local/bin/hello-world"]

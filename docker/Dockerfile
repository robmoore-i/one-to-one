FROM ocaml/opam2:ubuntu
COPY . /one-to-one
RUN cd /one-to-one && ./docker/linux-bootstrap.sh
WORKDIR /one-to-one
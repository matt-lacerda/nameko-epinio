FROM python@sha256:0768338d30b7195d518fe1ae22a75e0ed0947ceffd96699142cde8313d4e94ec as base
# CONFSTEP 1 - Change image to python:3.7-slim-bullseye because debian stretch (9) has reached EOF
# If debian 9 is strictly necessary, must change sources list to archive repos.

RUN apt-get update && \
    apt-get install --yes curl netcat

RUN pip3 install --upgrade pip
RUN pip3 install virtualenv

RUN virtualenv -p python3 /appenv

ENV PATH=/appenv/bin:$PATH

RUN groupadd -r nameko && useradd -r -g nameko nameko

RUN mkdir /var/nameko/ && chown -R nameko:nameko /var/nameko/

# ------------------------------------------------------------------------

FROM nameko-example-base as builder

RUN apt-get update && \
    apt-get install --yes build-essential autoconf libtool pkg-config \
    libgflags-dev libgtest-dev clang libc++-dev automake git libpq-dev

RUN pip install auditwheel

COPY . /application

ENV PIP_WHEEL_DIR=/application/wheelhouse
ENV PIP_FIND_LINKS=/application/wheelhouse

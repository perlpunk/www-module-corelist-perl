FROM alpine:latest

RUN apk --update --no-cache add \
    perl-app-cpanminus \
    perl-plack \
    perl-class-accessor \
    wget \
    make \
    gcc \
    perl-dev \
    musl-dev \
  && cpanm --notest \
    HTML::Template::Compiled \
    HTML::Template::Compiled::Plugin::HTML_Tags \
    Module::CoreList \
    YAML::PP \
    Starman \
  && apk del \
    gcc \
    perl-dev \
    musl-dev \
    wget \
    make \
  && rm -rf /root/.cpanm \
  && true

RUN adduser -h /home/corelist -D corelist

RUN mkdir /home/corelist/htc-cache && chown corelist.corelist /home/corelist/htc-cache

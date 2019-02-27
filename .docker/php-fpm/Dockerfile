FROM php:7.2-fpm-alpine
MAINTAINER Adrien MILLOT <adrien.millot@gmail.com>

RUN apk update \
    && apk upgrade

# For GD extension
RUN apk add --update --no-cache \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
&& docker-php-ext-install -j"$(getconf _NPROCESSORS_ONLN)" gd

# For APCu extension
RUN docker-php-source extract \
    && apk add --no-cache --virtual .phpize-deps-configure $PHPIZE_DEPS \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && apk del .phpize-deps-configure \
    && docker-php-source delete

# For intl extension
RUN apk add --no-cache icu-dev \
    && docker-php-ext-install intl

# For opcache extension
RUN docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install opcache

# For postgres extension
RUN apk add --no-cache postgresql-dev \
    && docker-php-ext-install \
       pdo \
       pdo_pgsql

# For redis extension
RUN docker-php-source extract \
    && apk add --no-cache --virtual .phpize-deps-configure $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .phpize-deps-configure \
    && docker-php-source delete

# For Xdebug
RUN apk --no-cache add --virtual .build-deps g++ autoconf make \
    && pecl channel-update pecl.php.net \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps \
&& rm -r /tmp/pear/*

WORKDIR '/var/www/html'

CMD ["php-fpm"]

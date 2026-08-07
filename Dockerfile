FROM wordpress:latest

RUN a2enmod headers ext_filter \
    && apt-get update \
    && apt-get install -y --no-install-recommends libtidy-dev libxml2-dev \
    && docker-php-ext-install tidy soap \
    && pecl install redis brotli \
    && docker-php-ext-enable tidy soap redis brotli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

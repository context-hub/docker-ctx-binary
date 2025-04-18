ARG COMPOSER_VERSION="2.8.4"

FROM composer:${COMPOSER_VERSION} AS composer
FROM php:8.3-cli-alpine

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apk add --no-cache \
    wget \
    git \
    unzip \
    upx \
    bash \
    file

COPY --from=composer /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /build-tools

# Clone and set up static-php-cli from source
RUN git clone https://github.com/crazywhalecc/static-php-cli.git
RUN composer install -d /build-tools/static-php-cli
RUN chmod +x static-php-cli/bin/spc

# Download box tool for PHAR creation
RUN wget -O /usr/local/bin/box "https://github.com/box-project/box/releases/download/4.6.6/box.phar" \
    && chmod +x /usr/local/bin/box

# Install UPX for compression
RUN cd /build-tools/static-php-cli && ./bin/spc install-pkg upx

# Make tools available in PATH
ENV PATH="/build-tools/static-php-cli/bin:$PATH"

# Create build directories
RUN mkdir -p /build-tools/build/phar /build-tools/build/bin

# Download required PHP extensions (pre-download to speed up builds)
RUN cd /build-tools/static-php-cli && \
    ./bin/spc download micro \
    --for-extensions=ctype,dom,filter,libxml,mbstring,phar,simplexml,sockets,tokenizer,xml,xmlwriter,curl \
    --with-php=8.3 \
    --prefer-pre-built

# Verify environment is ready
RUN cd /build-tools/static-php-cli && ./bin/spc doctor --auto-fix

# Pre-build micro.sfx with required extensions (for all supported platforms)
RUN cd /build-tools/static-php-cli && \
    ./bin/spc build ctype,dom,filter,libxml,mbstring,phar,simplexml,sockets,tokenizer,xml,xmlwriter,curl \
    --build-micro \
    --with-upx-pack

# Copy the micro.sfx to a known location for later reuse
RUN cp /build-tools/static-php-cli/buildroot/bin/micro.sfx /build-tools/build/bin/

# Default command to display info
CMD ["echo", "PHP Builder image is ready for use"]
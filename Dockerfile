FROM --platform=$BUILDPLATFORM alpine:3.18

# Output directory for the binary
RUN mkdir /output

RUN apk add --no-cache                       \
    build-base curl git pkgconfig            \
    glib-dev glib-static                     \
    expat-dev expat-static                   \
    lcms2-dev lcms2-static                   \
    libjpeg-turbo-dev libjpeg-turbo-static   \
    libpng-dev libpng-static                 \
    libwebp-dev libwebp-static               \
    giflib-dev giflib-static                 \
    tiff-dev                                 \
    zlib-dev zlib-static                     \
    zstd-dev zstd-static                     \
    libdeflate-dev libdeflate-static         \
    xz-dev xz-static                         \
    jbig2dec-dev                             \
    meson ninja

# Set the working directory
WORKDIR /workspace

# No TIFF static library is found. So we build it from source.
RUN curl -L https://download.osgeo.org/libtiff/tiff-4.7.1.tar.gz | tar xz  &&           \
    cd tiff-4.7.1  &&                                                                   \
    ./configure --prefix=/usr/local --enable-static --disable-shared --disable-docs  && \
    make -j$(nproc)  &&                                                                 \
    make install

RUN curl -L https://github.com/libvips/libvips/releases/download/v8.18.0/vips-8.18.0.tar.xz | tar xJ     && \
    cd vips-8.18.0  &&                                                                                      \
    meson setup build                                                                                       \
    --buildtype=release                                                                                     \
    --default-library=static                                                                                \
    -Dintrospection=disabled                                                                                \
    -Dmagick=disabled                                                                                       \
    -Dexamples=false                                                                                        \
    --prefer-static                                                                                      && \
    cd build                                                                                             && \
    meson configure -Dc_link_args="-static" -Dcpp_link_args="-static"                                    && \
    ninja                                                                                                && \
    find ./tools -maxdepth 1 -type f |xargs -i cp {} /output/                                            && \
    strip /output/*

# Output directory for the binary
WORKDIR /output

CMD ["sh"]

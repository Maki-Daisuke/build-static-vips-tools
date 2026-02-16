FROM alpine:3.23

# Output directory for the binary
RUN mkdir /output

# Set the working directory
WORKDIR /workspace

# Install build tools
RUN apk update &&                            \
    apk add --no-cache                       \
    build-base cmake curl git pkgconfig      \
    meson ninja patchelf

# Install Glib and its dependencies
RUN apk add --no-cache                       \
    glib-dev glib-static                     \
    expat-dev expat-static                   \
    libeconf-dev                             \
    libffi-dev                               \
    pcre2-dev pcre2-static                   \
    util-linux-dev util-linux-static

# Install image format libraries (apk available)
RUN apk add --no-cache                       \
    brotli-static brotli-dev                 \
    bzip2-static bzip2-dev                   \
    fftw-dev fftw-static                     \
    giflib-dev giflib-static                 \
    jbig2dec-dev                             \
    libdeflate-dev libdeflate-static         \
    libjpeg-turbo-dev libjpeg-turbo-static   \
    libpng-dev libpng-static                 \
    libwebp-dev libwebp-static               \
    xz-dev xz-static                         \
    zlib-dev zlib-static                     \
    zstd-dev zstd-static

# liborc for SIMD acceleration
RUN curl -L https://github.com/GStreamer/orc/archive/refs/tags/0.4.41.tar.gz | tar xz   && \
    cd orc-0.4.41                                                                       && \
    meson setup build --buildtype=release --default-library=static --prefix=/usr/local  && \
    ninja -C build                                                                      && \
    ninja -C build install

# CMake insists on linking with lcms2's .so, so we build statically-linked lcms2 from source instead of using apk.
RUN curl -L https://github.com/mm2/Little-CMS/releases/download/lcms2.18/lcms2-2.18.tar.gz | tar xz  && \
    cd lcms2-2.18                                                                                    && \
    ./configure --prefix=/usr/local --enable-static --disable-shared                                 && \
    make -j$(nproc) install

# libeconf (Glib dependency. We need to build it from source because apk version does not support static build)
RUN curl -L https://github.com/openSUSE/libeconf/archive/refs/tags/v0.8.3.tar.gz | tar xz  && \
    cd libeconf-0.8.3                                                                      && \
    meson setup build                                                                         \
    --buildtype=release                                                                       \
    --default-library=static                                                                  \
    --prefix=/usr/local                                                                    && \
    ninja -C build                                                                         && \
    ninja -C build install

# libimagequant for png optimization
RUN apk add --no-cache rust cargo                                                                  && \
    curl -L https://github.com/ImageOptim/libimagequant/archive/refs/tags/4.4.1.tar.gz | tar xz    && \
    cd libimagequant-4.4.1/imagequant-sys                                                          && \
    cargo build --release                                                                          && \
    cp ../target/release/libimagequant_sys.a /usr/local/lib/libimagequant.a                        && \
    cp libimagequant.h /usr/local/include                                                          && \
    echo 'prefix=/usr/local'                            >  /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'exec_prefix=\${prefix}'                       >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'libdir=\${exec_prefix}/lib'                   >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'includedir=\${prefix}/include'                >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo ''                                             >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'Name: imagequant'                             >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'Description: Palette quantization library'    >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'Version: 4.0.0'                               >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'Libs: -L\${libdir} -limagequant -lm -pthread' >> /usr/local/lib/pkgconfig/imagequant.pc  && \
    echo 'Cflags: -I\${includedir}'                     >> /usr/local/lib/pkgconfig/imagequant.pc

# Highway for SIMD intrinsics
RUN curl -L https://github.com/google/highway/releases/download/1.3.0/highway-1.3.0.tar.gz | tar xz  && \
    cd highway-1.3.0                                                                                 && \
    mkdir -p build                                                                                   && \
    cd build                                                                                         && \
    cmake ..                                                                                            \
    -DCMAKE_BUILD_TYPE=Release                                                                          \
    -DCMAKE_INSTALL_PREFIX=/usr/local                                                                   \
    -DBUILD_SHARED_LIBS=OFF                                                                             \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                                                \
    -DHWY_ENABLE_EXAMPLES=OFF                                                                           \
    -DHWY_ENABLE_TESTS=OFF                                                                              \
    -DHWY_ENABLE_CONTRIB=OFF                                                                         && \
    make -j$(nproc)  &&  make install

# libexif for rotation support
RUN curl -L https://github.com/libexif/libexif/releases/download/v0.6.25/libexif-0.6.25.tar.gz | tar xz  && \
    cd libexif-0.6.25                                                                                    && \
    ./configure --prefix=/usr/local --enable-static --disable-shared --disable-docs --disable-nls        && \
    make -j$(nproc)  &&  make install

# spng
RUN curl -L https://github.com/randy408/libspng/archive/refs/tags/v0.7.4.tar.gz | tar xz  && \
    cd libspng-0.7.4                                                                      && \
    meson build                                                                              \
    --buildtype=release                                                                      \
    --default-library=static                                                                 \
    --prefer-static                                                                          \
    -Dstatic_zlib=true                                                                    && \
    ninja -C build install

# No static library of TIFF is found. So we build it from source.
RUN curl -L https://download.osgeo.org/libtiff/tiff-4.7.1.tar.gz | tar xz                       && \
    cd tiff-4.7.1                                                                               && \
    ./configure --prefix=/usr/local --enable-static --disable-shared --with-pic --disable-docs  && \
    make -j$(nproc)  &&  make install

# OpenJPEG (JPEG2000)
RUN curl -L https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.4.tar.gz | tar xz  && \
    cd openjpeg-2.5.4                                                                       && \
    mkdir build && cd build                                                                 && \
    cmake ..                                                                                   \
    -DCMAKE_BUILD_TYPE=Release                                                                 \
    -DCMAKE_INSTALL_PREFIX=/usr/local                                                          \
    -DBUILD_SHARED_LIBS=OFF                                                                    \
    -DBUILD_STATIC_LIBS=ON                                                                     \
    -DBUILD_DOC=OFF                                                                            \
    -DBUILD_JPIP=OFF                                                                           \
    -DBUILD_JPWL=OFF                                                                           \
    -DBUILD_MJ2=OFF                                                                            \
    -DBUILD_TESTING=OFF                                                                     && \
    make -j$(nproc)  &&  make install

# libaom (for AVIF)
RUN apk add --no-cache nasm perl                                                      && \
    curl -L https://storage.googleapis.com/aom-releases/libaom-3.6.1.tar.gz | tar xz  && \
    cd libaom-3.6.1                                                                   && \
    cd build                                                                          && \
    cmake ..                                                                             \
    -DCMAKE_INSTALL_PREFIX=/usr/local                                                    \
    -DBUILD_SHARED_LIBS=0                                                                \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                                 \
    -DENABLE_DOCS=0                                                                      \
    -DENABLE_EXAMPLES=0                                                                  \
    -DENABLE_TESTDATA=0                                                                  \
    -DENABLE_TESTS=0                                                                     \
    -DENABLE_TOOLS=0                                                                  && \
    make -j$(nproc)  &&  make install

# libde265 (for HEIC)
RUN curl -L https://github.com/strukturag/libde265/releases/download/v1.0.16/libde265-1.0.16.tar.gz | tar xz  && \
    cd libde265-1.0.16                                                                                        && \
    ./configure --prefix=/usr/local --enable-static --disable-shared --disable-dec265 --disable-sherlock265   && \
    make -j$(nproc)  &&  make install

# libheif
RUN curl -L https://github.com/strukturag/libheif/releases/download/v1.17.6/libheif-1.17.6.tar.gz | tar xz  && \
    cd libheif-1.17.6                                                                                       && \
    cmake                                                                                                      \
    -DCMAKE_INSTALL_PREFIX=/usr/local                                                                          \
    -DBUILD_SHARED_LIBS=0                                                                                      \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                                                       \
    -DENABLE_PLUGIN_LOADING=0                                                                                  \
    -DWITH_EXAMPLES=0                                                                                          \
    -DBUILD_TESTING=OFF                                                                                        \
    -DWITH_GDK_PIXBUF=0                                                                                        \
    -DCMAKE_FIND_LIBRARY_SUFFIXES=".a"                                                                      && \
    make -j$(nproc)  &&  make install

# OpenEXR and Imath (OpenEXR dependency)
RUN curl -L https://github.com/AcademySoftwareFoundation/Imath/archive/refs/tags/v3.2.2.tar.gz | tar xz     && \
    cd Imath-3.2.2                                                                                          && \
    mkdir -p build && cd build                                                                              && \
    cmake ..                                                                                                   \
    -DCMAKE_BUILD_TYPE=Release                                                                                 \
    -DCMAKE_INSTALL_PREFIX=/usr/local                                                                          \
    -DBUILD_SHARED_LIBS=OFF                                                                                    \
    -DBUILD_TESTING=OFF                                                                                        \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                                                       \
    -DIMATH_INSTALL_PKG_CONFIG=ON                                                                           && \
    make -j$(nproc)  &&  make install                                                                       && \
    cd /workspace                                                                                           && \
    curl -L https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.4.4.tar.gz | tar xz   && \
    cd openexr-3.4.4                                                                                        && \
    mkdir -p build && cd build                                                                              && \
    cmake ..                                                                                                   \
    -DCMAKE_BUILD_TYPE=Release                                                                                 \
    -DCMAKE_INSTALL_PREFIX=/usr/local                                                                          \
    -DBUILD_SHARED_LIBS=OFF                                                                                    \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                                                       \
    -DOPENEXR_INSTALL_PKG_CONFIG=ON                                                                            \
    -DBUILD_TESTING=OFF                                                                                        \
    -DOPENEXR_BUILD_EXAMPLES=OFF                                                                               \
    -DOPENEXR_BUILD_TOOLS=OFF                                                                                  \
    -DOPENEXR_BUILD_TESTS=OFF                                                                                  \
    -DOPENEXR_BUILD_DOCS=OFF                                                                                && \
    make -j$(nproc)  &&  make install

# poppler for PDF
# We need to build cairo manually because the apk package is linked against X11.
RUN apk add --no-cache                                                          \
    fontconfig-dev fontconfig-static                                            \
    freetype-dev freetype-static                                                \
    pixman-dev pixman-static                                                 && \
    curl -L https://cairographics.org/releases/cairo-1.18.4.tar.xz | tar xJ  && \
    cd cairo-1.18.4                                                          && \
    meson setup build                                                           \
    --prefix=/usr/local                                                         \
    --buildtype=release                                                         \
    --default-library=static                                                    \
    -Dxcb=disabled                                                              \
    -Dxlib=disabled                                                             \
    -Dtests=disabled                                                            \
    -Dglib=enabled                                                              \
    -Dfontconfig=enabled                                                        \
    -Dfreetype=enabled                                                       && \
    ninja -C build install                                                   && \
    cd /workspace                                                           

RUN curl -L https://poppler.freedesktop.org/poppler-26.02.0.tar.xz | tar xJ  && \
    cd poppler-26.02.0                                                       && \
    mkdir -p build && cd build                                               && \
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig"     && \
    export CMAKE_PREFIX_PATH="/usr/local;/usr"                               && \
    cmake ..                                                                    \
    -DCMAKE_BUILD_TYPE=Release                                                  \
    -DCMAKE_INSTALL_PREFIX=/usr/local                                           \
    -DBUILD_SHARED_LIBS=OFF                                                     \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                        \
    -DCMAKE_PREFIX_PATH="/usr/local;/usr"                                       \
    -DCMAKE_FIND_LIBRARY_SUFFIXES=".a"                                          \
    -DTIFF_LIBRARY="/usr/local/lib/libtiff.a"                                   \
    -DTIFF_INCLUDE_DIR=/usr/local/include                                       \
    -Dlcms2_LIBRARY="/usr/local/lib/liblcms2.a"                                 \
    -Dlcms2_INCLUDE_DIR=/usr/local/include                                      \
    -DFontconfig_LIBRARY="/usr/lib/libfontconfig.a"                             \
    -DFREETYPE_LIBRARY="/usr/lib/libfreetype.a"                                 \
    -DJPEG_LIBRARY="/usr/lib/libjpeg.a"                                         \
    -DPNG_LIBRARY="/usr/lib/libpng.a"                                           \
    -DZLIB_LIBRARY="/usr/lib/libz.a"                                            \
    -DCMAKE_CXX_STANDARD_LIBRARIES="-Wl,-Bstatic -llcms2 -lopenjp2 -ltiff -lcairo -ldeflate -ljpeg -lwebp -lzstd -lpixman-1 -lgio-2.0 -lgobject-2.0 -lglib-2.0 -lfontconfig -llzma -lsharpyuv -lffi -lintl -lfreetype -lexpat -luuid -lbrotlidec -lbrotlicommon -lbz2 -lpng -leconf -lz -Wl,-Bdynamic" \
    -DCMAKE_EXE_LINKER_FLAGS="-static -L/usr/local/lib -L/usr/lib -pthread"     \
    -DENABLE_LIBTIFF=ON                                                         \
    -DENABLE_LCMS=ON                                                            \
    -DHAVE_JPEG_MEM_SRC=ON                                                      \
    -DENABLE_DCTDECODER=libjpeg                                                 \
    -DENABLE_NSS3=OFF                                                           \
    -DENABLE_GPGME=OFF                                                          \
    -DENABLE_QT5=OFF                                                            \
    -DENABLE_QT6=OFF                                                            \
    -DENABLE_BOOST=OFF                                                          \
    -DENABLE_LIBCURL=OFF                                                        \
    -DENABLE_GLIB=ON                                                            \
    -DENABLE_CPP=ON                                                             \
    -DENABLE_UTILS=ON                                                           \
    -DBUILD_TESTING=OFF                                                         \
    -DPOPPLER_BUILD_TESTS=OFF                                                   \
    -DPOPPLER_BUILD_DOCS=OFF                                                 && \
    make -j$(nproc)  &&  make install

# libvips
# gcc cannot detect posix_memalign somehow, but musl provides it. So, we explicitly define HAVE_POSIX_MEMALIGN.
# Linking vips-tool binaries are very memory intensive, because of the large number of dependencies linked statically.
# So, we use `ninja -j 4` instead of `ninja -j$(nproc)` to avoid OOM errors. You may tune this value according to your environment.
RUN curl -L https://github.com/libvips/libvips/releases/download/v8.18.0/vips-8.18.0.tar.xz | tar xJ       && \
    cd vips-8.18.0                                                                                         && \
    export LDFLAGS="-static -L/usr/local/lib -L/usr/lib -pthread -Wl,-Bstatic -llcms2 -lopenjp2 -ltiff -ldeflate -ljpeg -lwebp -lzstd -lpixman-1 -lgio-2.0 -lgobject-2.0 -lglib-2.0 -lfontconfig -llzma -lsharpyuv -lffi -lfreetype -lexpat -luuid -lbrotlidec -lbrotlicommon -lbz2 -lpng -leconf -lz -Wl,-Bdynamic" && \
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH                                       && \
    meson setup build                                                                                         \
    --buildtype=release                                                                                       \
    --default-library=static                                                                                  \
    --prefer-static                                                                                           \
    -Ddeprecated=false                                                                                        \
    -Dexamples=false                                                                                          \
    -Dcplusplus=false                                                                                         \
    -Dcpp-docs=false                                                                                          \
    -Ddocs=false                                                                                              \
    -Dmodules=disabled                                                                                        \
    -Dintrospection=disabled                                                                                  \
    -Dvapi=false                                                                                              \
    -Dmagick=disabled                                                                                         \
    -Dlcms=enabled                                                                                            \
    -Dhighway=enabled                                                                                         \
    -Dorc=enabled                                                                                             \
    -Dpoppler=enabled                                                                                         \
    -Dtiff=enabled                                                                                            \
    -Djpeg=enabled                                                                                            \
    -Dspng=enabled                                                                                            \
    -Dc_args="-DHAVE_ALIGNED_ALLOC=1 -DHAVE_POSIX_MEMALIGN=1"                                                 \
    -Dc_link_args="-static -leconf" -Dcpp_link_args="-static -leconf"                                      && \
    cd build  &&  ninja -j 4                                                                               && \
    find ./tools -maxdepth 1 -type f |xargs -i cp {} /output/                                              && \
    strip /output/*

# Output directory for the binary
WORKDIR /output

CMD ["sh"]

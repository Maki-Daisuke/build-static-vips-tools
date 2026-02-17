# Portable & Statically Linked Vips Tools for Linux

Build statically-linked, portable [libvips](https://www.libvips.org/) command-line tools (v8.18.0) for Linux — no runtime dependencies required.

## Overview

This project uses Docker to statically link libvips tools on Alpine Linux 3.23, generating standalone binaries with minimal dependencies.
The generated binaries operate independently of the libc and can run on most Linux environments as is.

### Output Binaries

The following vips command-line tools are built:

- `vips` — General-purpose image processing command
- `vipsthumbnail` — High-performance thumbnail generator
- `vipsedit` — Image metadata editor
- `vipsheader` — Image header/metadata viewer

### Supported Formats

| Format | Library | Version |
| ------ | ------- | ------- |
| JPEG | libjpeg-turbo | (Alpine package) |
| PNG | libpng + libspng + libimagequant | (Alpine) / 0.7.4 / 4.4.1 |
| WebP | libwebp | (Alpine package) |
| TIFF | libtiff | 4.7.1 |
| GIF | giflib | (Alpine package) |
| HEIF / HEIC | libheif + libde265 | 1.17.6 / 1.0.16 |
| AVIF | libheif + libaom | 1.17.6 / 3.6.1 |
| JPEG 2000 | OpenJPEG | 2.5.4 |
| OpenEXR | OpenEXR + Imath | 3.4.4 / 3.2.2 |
| FITS | cfitsio | 4.6.3 |
| PDF | poppler + cairo | 26.02.0 / 1.18.4 |
| SVG | librsvg | 2.61.4 |

Additional libraries:

| Library | Purpose | Version | Notes |
| ------- | ------- | ------- | ----- |
| lcms2 | ICC color management | 2.18 | |
| libexif | EXIF metadata / auto-rotation | 0.6.25 | |
| Highway | SIMD acceleration | 1.3.0 | |
| ORC | SIMD acceleration | 0.4.41 | |
| dav1d | AV1 decoder | 1.5.3 | Required by librsvg |
| libeconf | Configuration parser | 0.8.3 | Statically built (apk lacks static lib) |
| fftw | Fourier transform | (Alpine package) | |

## Prerequisites

- Docker with `buildx` support

### Cross-Compilation

If you need to cross-compile (e.g. build for ARM64 on x86_64), you must register QEMU user-mode emulation binaries:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

### Build Requirements

> [!NOTE]
> The final linking stage is very memory-intensive due to the large number of statically-linked dependencies.
> The build uses `ninja -j 2` (instead of `-j$(nproc)`) to avoid OOM errors.
> Ensure your Docker environment has sufficient memory (16 GB+ recommended) and disk space.

## Usage

### 1. Build using `docker buildx`

```bash
# Build for ARM64 (cross-compilation from x86_64)
docker buildx build --platform linux/arm64 -t vips-tools-arm64 --load .

# Build for x86_64 (native build)
docker buildx build --platform linux/amd64 -t vips-tools-amd64 --load .
```

This command will compile everything and place the resulting vips tools into `/output` directory in the container.

### 2. Create a container

```bash
docker create --name vips vips-tools-arm64
```

### 3. Extract the binaries

```bash
docker cp -a vips:/output - |tar -xf -
```

### 4. Use the binaries

```bash
# Generate a 256px thumbnail
./output/vipsthumbnail input.jpg -s 256 -o thumb.jpg

# View image metadata
./output/vipsheader input.png

# Convert between formats
./output/vips copy input.jpg output.webp
```

## License

This project is in the Public Domain.

[CC0 1.0 Universal (CC0 1.0) Public Domain Dedication](https://creativecommons.org/publicdomain/zero/1.0/)

To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.

## Author

Daisuke (yet another) Maki

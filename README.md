# Building Static Vips Tools

Dockerfile to build statically-linked portable binaries of vips-tools for Linux.

## Overview

This project uses Docker to statically link vips-tools on an Alpine Linux, generating standalone binaries with minimal dependencies.
The generated binaries operate independently of the libc and can run on most Linux environments as is.

## Prerequisites

If you need to cross-compile (e.g. build for ARM64 on x86_64), you must register QEMU user-mode emulation binaries:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

## Usage

### 1. Build using `docker buildx`

```bash
# Specify the platform to build for
docker buildx build --platform linux/arm64 -t vips-tools-arm64 --load .
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

## License

This project is in the Public Domain.

[CC0 1.0 Universal (CC0 1.0) Public Domain Dedication](https://creativecommons.org/publicdomain/zero/1.0/)

To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.

## Author

Daisuke (yet another) Maki

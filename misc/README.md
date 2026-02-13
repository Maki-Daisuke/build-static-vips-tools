# deporder.py

Parses a Graphviz `.dot` file representing package dependencies and outputs all transitive dependencies of a given package in topological order suitable for static linker flags.

## Usage

```bash
python misc/deporder.py <dotfile> <package-prefix>
```

- `<dotfile>` — A Graphviz `.dot` dependency graph file (e.g. `installed.dot`)
- `<package-prefix>` — Prefix string to match the starting package name

## Examples

```bash
# Typically, you can generate a clean dependency graph of a specific package using Docker:
docker run --rm alpine:3.23 sh -c 'apk update && apk add --no-cache vips-tools && apk dot --installed' > installed.dot

# Show the full dependency tree for vips-tools
python misc/deporder.py installed.dot vips-tools
```

## Output Format

```
-ljpeg  # libjpeg-turbo-3.1.2-r0
-lwebp  # libwebp-1.6.0-r0
-lz  # zlib-1.3.1-r2
# some-package-1.0-r0  (no library flags)
```

- Dependencies with `so:libXXX.so.N` labels are output as `-lXXX` linker flags
- Dependencies without such labels are shown as comments with the package name
- Packages prefixed with `musl-`, `busybox-`, or `alpine-` are automatically excluded

## Notes

- An error is raised if the prefix matches multiple packages
- The starting package itself is excluded from output
- A warning is printed to stderr if a cycle is detected in the graph

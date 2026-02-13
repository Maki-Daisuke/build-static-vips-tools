#!/usr/bin/env python3
"""Extract dependency order from a Graphviz .dot file.

Parses a .dot file representing package dependencies, finds all transitive
dependencies of a given package, and outputs them in topological order
suitable for static linker flags.

Usage:
    python deporder.py <dotfile> <package-prefix>

Example:
    python deporder.py installed.dot tiff
    python deporder.py installed.dot vips-8
"""

import re
import sys
from collections import defaultdict, deque

# Packages to exclude from output (always implicitly linked)
EXCLUDED_PACKAGES = {"musl-", "busybox-", "alpine-", "ca-certificates-", "pkgconf-"}


def parse_dot_file(filepath: str):
    """Parse a .dot file and extract the dependency graph.

    Returns:
        graph:         dict[str, set[str]] - package -> set of packages it depends on
        provided_libs: dict[str, set[str]] - package -> set of linker flags (e.g. {"-ljpeg"})
        all_nodes:     set[str]            - all package names found in the file
    """
    graph: dict[str, set[str]] = defaultdict(set)
    provided_libs: dict[str, set[str]] = defaultdict(set)
    all_nodes: set[str] = set()

    edge_re = re.compile(r'"([^"]+)"\s*->\s*"([^"]+)"\s*\[([^\]]*)\]')
    label_re = re.compile(r'label="([^"]*)"')
    so_lib_re = re.compile(r"^so:lib(.+?)\.so(?:\.\d+)*$")

    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            edge_match = edge_re.search(line)
            if not edge_match:
                continue

            source = edge_match.group(1)
            target = edge_match.group(2)
            attrs = edge_match.group(3)

            all_nodes.add(source)
            all_nodes.add(target)

            # source depends on target
            graph[source].add(target)

            # Extract linker flag from "so:libXXX.so.N" label
            label_match = label_re.search(attrs)
            if label_match:
                so_match = so_lib_re.match(label_match.group(1))
                if so_match:
                    lib_name = so_match.group(1)
                    provided_libs[target].add(f"-l{lib_name}")

    return graph, provided_libs, all_nodes


def find_package(all_nodes: set[str], prefix: str) -> str:
    """Find a single package by prefix match.

    Raises SystemExit if no match or ambiguous match is found.
    """
    matches = sorted(node for node in all_nodes if node.startswith(prefix))

    if not matches:
        print(f"Error: no package matching prefix '{prefix}'", file=sys.stderr)
        sys.exit(1)

    if len(matches) == 1:
        return matches[0]

    # Exact match takes priority
    if prefix in matches:
        return prefix

    print(
        f"Error: ambiguous prefix '{prefix}', matches:\n"
        + "\n".join(f"  - {m}" for m in matches),
        file=sys.stderr,
    )
    sys.exit(1)


def is_excluded(package_name: str) -> bool:
    """Check if a package should be excluded from output."""
    return any(package_name.startswith(prefix) for prefix in EXCLUDED_PACKAGES)


def collect_dependencies(graph: dict[str, set[str]], start: str) -> set[str]:
    """BFS to collect all transitive dependencies from a starting package."""
    visited: set[str] = set()
    queue = deque([start])

    while queue:
        node = queue.popleft()
        if node in visited:
            continue
        visited.add(node)
        for dep in graph.get(node, set()):
            if dep not in visited:
                queue.append(dep)

    return visited


def topological_sort(graph: dict[str, set[str]], nodes: set[str]) -> list[str]:
    """Topological sort: dependents first, leaf dependencies last.

    This produces the correct order for linker flags where the linker
    processes libraries left-to-right and resolves symbols on demand.
    """
    # Build sub-graph with only the specified nodes
    in_degree: dict[str, int] = {node: 0 for node in nodes}
    sub_graph: dict[str, list[str]] = defaultdict(list)

    for node in nodes:
        for dep in graph.get(node, set()):
            if dep in nodes:
                sub_graph[node].append(dep)
                in_degree[dep] += 1

    # Kahn's algorithm (stable: ties broken alphabetically)
    queue = deque(sorted(n for n in nodes if in_degree[n] == 0))
    result: list[str] = []

    while queue:
        node = queue.popleft()
        result.append(node)
        for dep in sorted(sub_graph[node]):
            in_degree[dep] -= 1
            if in_degree[dep] == 0:
                queue.append(dep)

    if len(result) != len(nodes):
        remaining = nodes - set(result)
        print(
            f"Warning: cycle detected involving: {', '.join(sorted(remaining))}",
            file=sys.stderr,
        )
        result.extend(sorted(remaining))

    return result


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)

    dot_file = sys.argv[1]
    prefix = sys.argv[2]

    graph, provided_libs, all_nodes = parse_dot_file(dot_file)

    start = find_package(all_nodes, prefix)
    print(f"# Starting from: {start}", file=sys.stderr)

    # Collect and sort all transitive dependencies
    deps = collect_dependencies(graph, start)
    sorted_deps = topological_sort(graph, deps)

    # Output in linker order (skip the starting package itself and excluded ones)
    for pkg in sorted_deps:
        if pkg == start or is_excluded(pkg):
            continue

        libs = provided_libs.get(pkg)
        if libs:
            print(f"{' '.join(sorted(libs))}  # {pkg}")
        else:
            print(f"# {pkg}  (no library flags)")


if __name__ == "__main__":
    main()

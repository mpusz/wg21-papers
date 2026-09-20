# Standardese wording: quantities and units

Formal wording for the quantities and units library proposed by
[P3045](../src/3045R10_quantities_and_units_library.md), written in the same
LaTeX dialect as the C++ working draft so that it can be lifted into it.

Moved here from the mp-units repository in September 2026. It lived under
`docs/reference/api_reference/src/` and doubled as that project's published API
reference, which meant every documentation build needed LaTeX, Haskell and Node.
mp-units now generates its API reference from the headers with
[MrDocs](https://www.mrdocs.com), so the wording no longer has a second job, and
belongs with the papers it is wording *for*.

## Contents

| File | |
|---|---|
| `quantities.tex` | the wording, ~6700 lines |
| `intro.tex` | front matter |
| `macros_extensions.tex` | macros beyond the working draft's own |
| `CMakeLists.txt` | build definition, via `jegp_add_standardese_sources` |
| `build.sh` | fetches the toolchain and builds |

## Building

```shell
./build.sh
```

Output lands in `build/`, as `mp-units.html` and `mp-units.pdf`. The script
prints the system packages it needs first; `./build.sh -s` configures without
building.

Three repositories are cloned into `.deps/` on first run:
[jegp.cmake_modules](https://github.com/JohelEGP/jegp.cmake_modules), and the
`standardese_sources_base` branches of
[draft](https://github.com/JohelEGP/draft) and
[cxxdraft-htmlgen](https://github.com/JohelEGP/cxxdraft-htmlgen).

This is neither of the frameworks `src/` uses. It is the pipeline the working
draft itself is built with, which is why the dependency list is what it is.

## Keeping it current

The wording describes the library's design, not its implementation, so it does
not have to track every mp-units commit. It does have to track the design, and
nothing checks that automatically any more: when a paper revision changes the
model, the wording is the thing that has to say so.

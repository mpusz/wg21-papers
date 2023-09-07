# My ISO C++ Committee (WG21) papers

This repo contains ISO C++ Committee (WG21) papers that I created or co-authored with other
C++ experts.

[src](src) directory contains source version of those documents. They are written in markdown-like
language. Depending on the file extension the paper using either:

- [Bikeshed](https://github.com/tabatkins/bikeshed),
- [mpark/wg21](https://github.com/mpark/wg21),

for their processing.

Generated outcome documents can be found on [GitHub IO](https://mpusz.github.io/wg21-papers)
page.


## Getting started

### Bikeshed

1. Bikeshed is really simple to install

    ```shell
    git clone https://github.com/tabatkins/bikeshed.git
    pip2 install --editable /path/to/cloned/bikeshed
    bikeshed update
    ```

2. Updating Bikeshed to the latest version and state requires the following steps

    ```shell
    git pull --rebase
    bikeshed update
    ```

3. To develop a document with Bikeshed the most useful is

    ```shell
    bikeshed watch src/paper_to_generate.bs
    ```

For more information refer to [Bikeshed Documentation](https://tabatkins.github.io/bikeshed/).

### mpark/wg21

1. Framework usage is nicely described int the [README documentation](https://github.com/mpark/wg21)
   on the project's website.

### markdownlint and VS code

The repository provides a support for [markdownlint](https://github.com/DavidAnson/markdownlint)
to ensure that markdown documents are compliant and consistent. To use this feature just install
[markdownlint plugin](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)
in VS Code.

## Generating docs

1. Change the active directory to the `src` subdirectory
2. Type `make` and press TAB to see the list of available targets
3. Provide the target and press ENTER

For example:

```shell
cd src
make 2008R1_enable_variable_template_template_parameters.html 
```

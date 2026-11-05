# websh container images

[websh](https://github.com/apache/tcl-websh), the Tcl web framework from the Apache Tcl
project, for `linux/amd64` and `linux/arm64`: the `websh` interpreter for CGI and scripts, and
an Apache httpd 2.4 image with `mod_websh`.

These are community images. They are not published by the Apache Software Foundation.

## What is inside

websh 3.6.0b5 is the last websh release (2009). These images build the last commit of the
websh repository (2018, `f3dee46`), which adds Apache 2.4 support for `mod_websh` and builds
with current compilers. websh itself reports version `3.6.0b5`.

websh supports Tcl 8.x only; Tcl 9 would need a port of its C code. The images are built on
the [Tcl images](https://github.com/vrtexe/tcl-docker) (`ghcr.io/vrtexe/tcl`): websh is
compiled on the Tcl `-dev` image and copied into the matching runtime image, so it uses exactly
that Tcl build.

| Tcl | Status |
|---|---|
| 8.6.18 | current (`latest`) |
| 8.5.19 | last 8.5 release |
| 8.5.13 | legacy, for applications pinned to this patch level |

## Variants

| Variant | Tag suffix | Base | Contents |
|---|---|---|---|
| Debian slim | none, `-slim` | `tcl:<v>-slim-trixie` | `websh` interpreter and the `websh` Tcl package |
| Alpine | `-alpine` | `tcl:<v>-alpine3.24` | the same, smallest |
| Rocky Linux 9 | `-rocky9-minimal` | `tcl:<v>-rocky9-minimal` | the same |
| Rocky Linux 8 | `-rocky8-minimal` | `tcl:<v>-rocky8-minimal` | the same |
| Apache | `-apache` | `tcl:<v>-slim-trixie` | Apache httpd 2.4 with `mod_websh` and CGI (see [Usage](#usage)) |
| Apache on Rocky Linux 9 | `-rocky9-minimal-apache` | `tcl:<v>-rocky9-minimal` | the same with Rocky Linux's httpd |
| Apache on Rocky Linux 8 | `-rocky8-minimal-apache` | `tcl:<v>-rocky8-minimal` | the same with Rocky Linux's httpd |
| Apache on Alpine | `-alpine-apache`, `-alpine3.24-apache` | `tcl:<v>-alpine3.24` | the same with Alpine's httpd, smallest |

The Apache images run httpd with the `prefork` MPM: with worker threads, Tcl 8.5's C stack
check computes a wrong limit inside Apache's threads and fails every request with
"out of stack space".

## Tags

`<websh>-tcl<tcl>-<variant>`: websh version first (`3.6.0b5` or `3.6`), then the Tcl it is
built on. The Tcl part follows the newest release of each line: `tcl8.6` is the newest 8.6,
`tcl8` the newest 8.x. Images on the newest Tcl also get tags without the Tcl part.

| Example | Means |
|---|---|
| `3.6`, `latest` | websh 3.6 on the newest Tcl, Debian slim |
| `3.6-alpine`, `alpine` | websh 3.6 on the newest Tcl, Alpine |
| `3.6-apache`, `apache` | websh 3.6 with Apache on the newest Tcl |
| `3.6-tcl8.5-slim` | websh 3.6 on the newest Tcl 8.5 |
| `3.6.0b5-tcl8.5.13-rocky8-minimal` | websh 3.6.0b5 on exactly Tcl 8.5.13, Rocky Linux 8 |

Applications that need an exact Tcl patch level (`package require -exact Tcl 8.5.13`) must use
the full Tcl version in the tag. All tags are rebuilt monthly for operating system fixes; pin a
digest (`@sha256:...`) to freeze an image.

Every tag holds both architectures. Images are published to the GitHub Container Registry
(`ghcr.io/vrtexe/websh`) and Docker Hub (`docker.io/<user>/websh`) with identical digests.

## Usage

The `websh` interpreter, for scripts and as a CGI program behind any web server:

```sh
docker run --rm -it ghcr.io/vrtexe/websh:3.6                       # interactive websh
docker run --rm -v "$PWD":/app -w /app ghcr.io/vrtexe/websh:3.6-alpine websh script.ws3
```

websh as a package in plain `tclsh`:

```tcl
package require websh
```

Apache with `mod_websh`:

```sh
docker run --rm -p 8080:80 -v "$PWD/htdocs":/var/www/html ghcr.io/vrtexe/websh:3.6-apache
# http://localhost:8080/hello.ws3
```

```tcl
# htdocs/hello.ws3
web::command default {
    web::put "hello [web::param name]"
}
web::dispatch
```

By default each `.ws3` file gets its own interpreter, like CGI. For shared interpreter pools
or templated `.html`, add a `WebshConfig` file to the Apache configuration; see the websh
documentation.

Apache with CGI: every Apache image also runs websh scripts as CGI programs, one process per
request, the way many websh applications are deployed. Put executable scripts that start with
`#!/usr/local/bin/websh` in the CGI directory, served under `/cgi-bin/`:

| Image | CGI directory |
|---|---|
| `-apache` (Debian) | `/usr/lib/cgi-bin` |
| `-rocky9-minimal-apache`, `-rocky8-minimal-apache`, `-alpine-apache` | `/var/www/cgi-bin` |

```sh
docker run --rm -p 8080:80 -v "$PWD/cgi-bin":/usr/lib/cgi-bin ghcr.io/vrtexe/websh:3.6-apache
# http://localhost:8080/cgi-bin/hello.cgi
```

Both modes work side by side; which one a script uses depends only on where it is.

## Repository layout

The same layout as the official Docker images and the Tcl images:

- `versions.json` lists the websh commit and checksum, the Tcl versions and the variants.
- The `Dockerfile-*.template` files are the build recipes.
- `apply-templates.sh` renders `tcl<version>/<variant>/Dockerfile`; the rendered files are
  committed, so each one can be built on its own: `docker build tcl8.6.18/alpine3.24`.
- `tags.sh <tcl-version> <variant>` prints the tags for one image.
- `test.sh <image> <tcl-version> [apache]` smoke-tests an image: versions, CPU, the Tcl
  package, a CGI request, and for `apache` an HTTP request through `mod_websh`.

## Building locally

```sh
docker build -t websh-local tcl8.6.18/alpine3.24
./test.sh websh-local 8.6.18
docker build -t websh-apache tcl8.6.18/apache
./test.sh websh-apache 8.6.18 apache
```

With podman, pass `--platform` and set `ENGINE=podman` for `test.sh`.

## CI

`.github/workflows/build.yml` builds every image natively on amd64 and arm64 runners and runs
`test.sh` on each. Pushes to `main` and the monthly rebuild publish multi-arch tags to GHCR,
then one job mirrors them to Docker Hub with `skopeo`. It needs the repository variable
`DOCKERHUB_USERNAME` and the secret `DOCKERHUB_TOKEN`; without them only GHCR is published.
After the first push, set the `websh` package to public under the package settings.

## License

The files in this repository are under the MIT License, see [LICENSE](LICENSE).

websh is distributed under the Apache License 2.0 and Tcl under its BSD-style license; each
image carries them at `/usr/local/share/licenses/websh/` (with websh's `NOTICE`) and
`/usr/local/share/licenses/tcl/`.

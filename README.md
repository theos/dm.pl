# dm.pl
A basic Perl program that makes Debian software packages (.deb files) without needing dpkg installed. It works as a drop-in replacement for `dpkg-deb -b`, with compatible flags.

## Installation
dm.pl is included with and used by Theos, so if you’re using an up-to-date version of Theos you already have access to it! If you believe that you're using a legacy version of Theos, see [here](https://theos.dev/docs/upgrading-from-legacy-theos) for how to update.

Otherwise, you can either install with npm:

```bash
npm install -g @theosdev/dm.pl
```

…or clone a copy of this repo:

```bash
git clone https://github.com/theos/dm.pl.git
```

…and immediately start using it.

This will work on any system with Perl and xz-utils installed. (If you’re not sure, they almost certainly are already installed by your OS.)

## Synopsis
```
dm.pl [options] <directory> <package>
```

## Options
* **`-b`**: This option exists solely for compatibility with dpkg-deb.
* **`-Z<compression>`**: Specify the package compression type. Valid values are gzip (default), bzip2, lzma, xz and cat (no compression).
* **`-z<compress-level>`**: Specify the package compression level. Valid values are between 0 and 9. Default is 9 for bzip2, 6 for others, and 0 is equivalent to cat. Refer to **gzip(1)**, **bzip2(1)**, **xz(1)** for explanations of what effect each compression level has.
* **`--help`, `-?`**: Print a brief help message and exit.
* **`--man`**: Print a manual page and exit.

## License
Licensed under the MIT License. Refer to [LICENSE.md](LICENSE.md).

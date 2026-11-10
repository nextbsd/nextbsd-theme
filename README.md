# nextbsd-theme

A dark GNUstep theme for NextBSD. The bundle is named `NextBSD.theme`.

## Build and install

```sh
gmake install
```

As a normal user with `GNUSTEP_INSTALLATION_DOMAIN=USER`, this installs to `~/Library/Themes`.

## Activate

```sh
defaults write NSGlobalDomain GSTheme NextBSD
```

Restart your GNUstep apps to pick it up.

## Regenerate the colors

`ThemeColors.clr` is generated from the design tokens in `Tools/make-colors.m`:

```sh
cd Tools && gmake && cd .. && Tools/obj/make-colors
```

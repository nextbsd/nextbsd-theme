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

## Desktop defaults

A theme declares the desktop's defaults, and each user can override them
in Workspace Preferences. Any GNUstep theme can declare them: put the keys
at the top level of the theme's Info.plist (not inside `GSThemeDomain`).
The NextBSD theme declares:

```
NBDockPosition = right;
NBWindowMode = stacking;
NBMenuStyle = nextstep;
NBMinimizeStyle = dock;
```

| Key | Values | Built-in default |
|---|---|---|
| `NBDockPosition` | `right`, `left`, `top`, `bottom` | `right` |
| `NBWindowMode` | `stacking`, `tiling` | `stacking` |
| `NBMenuStyle` | `nextstep` (floating, tear-off), `inwindow`, `macmenubar` | `nextstep` |
| `NBMinimizeStyle` | `nextstep` (GNUstep miniwindows), `previews` (WindowServer tiles), `dock` (live previews in the Dock) | `dock` |

Each value is looked up in this order:

1. **The user's choice:** the same key in the user's defaults, in
   `NSGlobalDomain` (Workspace Preferences writes it there). No value
   means "Use theme default".
2. **The active theme's default:** the key in
   `[[GSTheme theme] infoDictionary]`.
3. **The built-in default** in the table.

A value that isn't one of the listed ones is skipped. After changing one,
a settings app posts the distributed notification
`org.nextbsd.DesktopSettingsChanged`, with the changed key as `key` in the
user info. `NBDesktopSettings.h` is the reference lookup; it isn't
installed, and the NextBSD backend and Workspace each carry a copy.

For example, to try NeXT miniwindows and then go back to the theme's
choice:

```sh
defaults write NSGlobalDomain NBMinimizeStyle nextstep
defaults delete NSGlobalDomain NBMinimizeStyle
```

Window mode and menu style are declared already, for the tiling and menu
work still to come; nothing reads them yet.

## Miniwindow icons

With NeXT miniwindows (`NBMinimizeStyle = nextstep`), GNUstep draws the
window's icon at its own size, so a 64×64 app icon would cover the title.
While the theme is active, it scales any miniwindow icon larger than three
quarters of the miniwindow (48×48 at 64) down to fit, by wrapping
libs-gui's private `NSMiniWindowView -setImage:` at run time. The wrapper
only resizes the image and then calls libs-gui's own method; it does
nothing if that class or method is missing.

## Regenerate the colors

`ThemeColors.clr` is generated from the design tokens in `Tools/make-colors.m`:

```sh
cd Tools && gmake && cd .. && Tools/obj/make-colors
```

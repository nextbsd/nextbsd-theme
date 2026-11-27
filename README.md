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
NBDockStyle = nextstep;
NBScrollerStyle = nextstep;
NBAppearance = dark;
NBWindowStyle = nextstep;
NBModeDefaults = {
    stacking = { NBDockPosition = right; NBMenuStyle = nextstep; };
    tiling = { NBDockPosition = bottom; NBMenuStyle = inwindow; };
};
```

| Key | Values | Built-in default |
|---|---|---|
| `NBDockPosition` | `right`, `left`, `top`, `bottom` | `right` |
| `NBWindowMode` | `stacking`, `tiling` | `stacking` |
| `NBMenuStyle` | `nextstep` (floating, tear-off), `inwindow`, `macmenubar` | `nextstep` |
| `NBMinimizeStyle` | `nextstep` (GNUstep miniwindows), `previews` (WindowServer tiles), `dock` (live previews in the Dock) | `dock` |
| `NBDockStyle` | `nextstep` (a tile behind each icon, no separators), `mac` (separators on a see-through panel), `tiling` (clear, with separators) | `nextstep` |
| `NBScrollerStyle` | `nextstep` (left, both arrows at the bottom), `mac` (right, both arrows at the bottom), `split` (right, an arrow at each end) | `nextstep` |
| `NBAppearance` | `dark`, `light` | `dark` |
| `NBWindowStyle` | `nextstep` (miniaturize left, close right, faint until hovered), `mac` (traffic lights at the left: close, minimize, zoom), `tiling` (minimize, maximize, close at the right, as on Windows) | `nextstep` |

Each value is looked up in this order:

1. **The user's choice:** the same key in the user's defaults, in
   `NSGlobalDomain` (Workspace Preferences writes it there). No value
   means "Use theme default".
2. **The active theme's default:** the key in
   `[[GSTheme theme] infoDictionary]`.
3. **The built-in default** in the table.

### Per-mode defaults

The Dock position and the menu style are kept for each window mode, so
switching between stacking and tiling brings that mode's set with it. In
the NextBSD theme:

| Window mode | Dock position | Menu style |
|---|---|---|
| **Stacking** (the theme's default mode) | right | NeXT |
| **Tiling** | bottom | in-window |

A theme declares them in `NBModeDefaults`, one dictionary per mode, and a
user's own choices go in `NBModeSettings` in `NSGlobalDomain`, the same
shape. For `NBDockPosition` and `NBMenuStyle`, in the current mode
(`NBWindowMode`, looked up as above):

1. **The user's choice for the mode:** `NBModeSettings[mode]`. In
   stacking, a plain `NBDockPosition` or `NBMenuStyle` in the user's
   defaults (from before settings were kept per mode) counts as the
   user's stacking choice; settings apps move it into
   `NBModeSettings.stacking` the next time they write one.
2. **The theme's default for the mode:** `NBModeDefaults[mode]`.
3. **The theme's plain key,** for themes without `NBModeDefaults`.
4. **The built-in default.**

For example, to keep the Dock on the left while tiling only:

```sh
defaults write NSGlobalDomain NBModeSettings '{ tiling = { NBDockPosition = left; }; }'
```

A value that isn't one of the listed ones is skipped. After changing one,
a settings app posts the distributed notification
`org.nextbsd.DesktopSettingsChanged`, with the changed key as `key` in the
user info. `NBDesktopSettings.h` is the reference lookup; it isn't
installed, and the NextBSD backend, the Dock and Workspace each carry a copy.

For example, to try NeXT miniwindows and then go back to the theme's
choice:

```sh
defaults write NSGlobalDomain NBMinimizeStyle nextstep
defaults delete NSGlobalDomain NBMinimizeStyle
```

Workspace Preferences switches the window mode: it sets WindowServer's
`WindowMode` (nextbsd/apps-windowserver, "Window tiling") and posts the
notification for the mode, the Dock position and the menu style, so the
Dock moves and running apps change their menus at once.

## The Help menu

Every app's Help menu starts with what macOS has there
(`NBHelpMenu.m`):

- **Search** (Command-?), drawn as a search field. Choosing it opens the
  search in the Help menu's place: typing lists help topics from every
  help book and the app's own menu commands. Choosing a topic shows it
  in Help; choosing a command opens the menus down to it, highlighted,
  until the next click or key (a click on it, or Return, chooses it).
  **Show all results** searches in Help.
- ***App* Help**, when the app has a book: a `.help` bundle in its
  Resources, named after its executable or by `GSHelpContentsFile`.
- **NextBSD Help** and **Keyboard Shortcuts**, from NextBSD Help.

Then the app's own items, without those that would open the same book
(`-showHelp:` items, and one called "*App* Help" when the app has a
book). An app with no Help menu gets one. Help.app
(nextbsd/apps-help) shows the books: a running Help through
Distributed Objects (`org.nextbsd.Help`), otherwise started with
`-NBHelpBook`, `-NBHelpTopic` and `-NBHelpSearch`. Its README describes
the book format.

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

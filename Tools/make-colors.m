/* Writes ThemeColors.clr from the locked NextBSD design tokens. */
#import <AppKit/AppKit.h>

static NSColor *
hex (unsigned value)
{
  return [NSColor colorWithCalibratedRed:((value >> 16) & 255) / 255.0
                                   green:((value >> 8) & 255) / 255.0
                                    blue:(value & 255) / 255.0
                                   alpha:1.0];
}

int
main (int argc, const char *argv[])
{
  CREATE_AUTORELEASE_POOL (pool);
  [NSApplication sharedApplication];
  /* The redesign (nextbsd/nextbsd#708, mockups/desktop.html): a cool,
     blue-tinted dark grey with the cyan accent. */
  unsigned black = 0x000000, page = 0x0b0c10, plane = 0x15171c, row = 0x17191f, line = 0x23262e;
  unsigned control = 0x23262e, border = 0x3a3f4b, title = 0x111318, dim = 0x6b6f7c;
  unsigned label = 0x9a9daa, text = 0xe3e5ea, accent = 0x00d4ff, selection = 0x1b4a63;
  struct { NSString *name; unsigned color; } colors[] = {
    {@"alternateSelectedControlColor", selection}, {@"alternateSelectedControlTextColor", 0xffffff},
    {@"controlBackgroundColor", plane}, {@"controlColor", control},
    {@"controlDarkShadowColor", black}, {@"controlHighlightColor", border},
    {@"controlLightHighlightColor", border}, {@"controlShadowColor", page},
    {@"controlTextColor", text}, {@"disabledControlTextColor", dim},
    {@"gridColor", line}, {@"headerColor", plane}, {@"headerTextColor", label},
    {@"highlightColor", border}, {@"keyboardFocusIndicatorColor", accent},
    {@"knobColor", border}, {@"labelColor", text}, {@"secondaryLabelColor", label},
    {@"tertiaryLabelColor", dim}, {@"quaternaryLabelColor", dim},
    {@"scrollBarColor", plane}, {@"secondarySelectedControlColor", 0x2c3038},
    {@"selectedControlColor", selection}, {@"selectedControlTextColor", 0xffffff},
    {@"selectedKnobColor", label}, {@"selectedMenuItemColor", selection},
    {@"selectedMenuItemTextColor", 0xffffff}, {@"selectedTextBackgroundColor", selection},
    {@"selectedTextColor", 0xffffff}, {@"shadowColor", black},
    {@"textBackgroundColor", page}, {@"textColor", text},
    {@"windowBackgroundColor", plane}, {@"windowFrameColor", title},
    {@"windowFrameTextColor", 0xe9eaef}, {@"rowBackgroundColor", plane},
    {@"alternateRowBackgroundColor", row}, {@"toolTipColor", 0x1a1d24},
    {@"toolTipTextColor", text},
    {@"terminalBackgroundColor", 0x1e1e1e}, {@"terminalBlueColor", 0x6fb3ff},
    {@"terminalBlackColor", 0x8a8a8a},
  };
  NSColorList *list = AUTORELEASE ([[NSColorList alloc] initWithName:@"System"]);
  for (size_t i = 0; i < sizeof (colors) / sizeof (colors[0]); i++)
    [list setColor:hex (colors[i].color) forKey:colors[i].name];
  BOOL ok = [list writeToFile:@"ThemeColors.clr"];
  NSColorList *extra = AUTORELEASE ([[NSColorList alloc] initWithName:@"ThemeExtra"]);
  [extra setColor:hex (selection) forKey:@"highlightedTableRowBackgroundColor"];
  [extra setColor:hex (text) forKey:@"highlightedTableRowTextColor"];
  ok = [extra writeToFile:@"ThemeExtraColors.clr"] && ok;
  RELEASE (pool);
  return ok ? 0 : 1;
}

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
  unsigned black = 0x000000, plane = 0x16161b, control = 0x26262d, raised = 0x33333a;
  unsigned bevel = 0x55555f, shade = 0x0a0a0a, label = 0xb8b8c0, text = 0xf5f5f7, accent = 0x00d4ff, selection = 0x0a5fd1;
  struct { NSString *name; unsigned color; } colors[] = {
    {@"alternateSelectedControlColor", selection}, {@"alternateSelectedControlTextColor", text},
    {@"controlBackgroundColor", plane}, {@"controlColor", control},
    {@"controlDarkShadowColor", shade}, {@"controlHighlightColor", bevel},
    {@"controlLightHighlightColor", bevel}, {@"controlShadowColor", shade},
    {@"controlTextColor", text}, {@"disabledControlTextColor", bevel},
    {@"gridColor", raised}, {@"headerColor", control}, {@"headerTextColor", label},
    {@"highlightColor", bevel}, {@"keyboardFocusIndicatorColor", accent},
    {@"knobColor", bevel}, {@"labelColor", text}, {@"secondaryLabelColor", label},
    {@"tertiaryLabelColor", label}, {@"quaternaryLabelColor", label},
    {@"scrollBarColor", control}, {@"secondarySelectedControlColor", raised},
    {@"selectedControlColor", selection}, {@"selectedControlTextColor", text},
    {@"selectedKnobColor", label}, {@"selectedMenuItemColor", text},
    {@"selectedMenuItemTextColor", black}, {@"selectedTextBackgroundColor", selection},
    {@"selectedTextColor", text}, {@"shadowColor", black},
    {@"textBackgroundColor", black}, {@"textColor", text},
    {@"windowBackgroundColor", plane}, {@"windowFrameColor", black},
    {@"windowFrameTextColor", text}, {@"rowBackgroundColor", plane},
    {@"alternateRowBackgroundColor", plane}, {@"toolTipColor", control},
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

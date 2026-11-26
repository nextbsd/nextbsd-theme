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

/* One appearance's tokens (nextbsd/nextbsd#708, mockups/desktop.html). */
struct palette
{
  unsigned black, page, plane, row, line, control, border, title, dim;
  unsigned label, text, accent, selection, selectedText, frameText, tip, secondarySelection;
};

static BOOL
write_lists (const struct palette *p, NSString *colorsFile)
{
  struct { NSString *name; unsigned color; } colors[] = {
    {@"alternateSelectedControlColor", p->selection},
    {@"alternateSelectedControlTextColor", p->selectedText},
    {@"controlBackgroundColor", p->plane}, {@"controlColor", p->control},
    {@"controlDarkShadowColor", p->black}, {@"controlHighlightColor", p->border},
    {@"controlLightHighlightColor", p->border}, {@"controlShadowColor", p->page},
    {@"controlTextColor", p->text}, {@"disabledControlTextColor", p->dim},
    {@"gridColor", p->line}, {@"headerColor", p->plane}, {@"headerTextColor", p->label},
    {@"highlightColor", p->border}, {@"keyboardFocusIndicatorColor", p->accent},
    {@"knobColor", p->border}, {@"labelColor", p->text}, {@"secondaryLabelColor", p->label},
    {@"tertiaryLabelColor", p->dim}, {@"quaternaryLabelColor", p->dim},
    {@"scrollBarColor", p->plane}, {@"secondarySelectedControlColor", p->secondarySelection},
    {@"selectedControlColor", p->selection}, {@"selectedControlTextColor", p->selectedText},
    {@"selectedKnobColor", p->label}, {@"selectedMenuItemColor", p->selection},
    {@"selectedMenuItemTextColor", p->selectedText},
    {@"selectedTextBackgroundColor", p->selection},
    {@"selectedTextColor", p->selectedText}, {@"shadowColor", 0x000000},
    {@"textBackgroundColor", p->page}, {@"textColor", p->text},
    {@"windowBackgroundColor", p->plane}, {@"windowFrameColor", p->title},
    {@"windowFrameTextColor", p->frameText}, {@"rowBackgroundColor", p->plane},
    {@"alternateRowBackgroundColor", p->row}, {@"toolTipColor", p->tip},
    {@"toolTipTextColor", p->text},
    {@"terminalBackgroundColor", 0x1e1e1e}, {@"terminalBlueColor", 0x6fb3ff},
    {@"terminalBlackColor", 0x8a8a8a},
  };
  NSColorList *list = AUTORELEASE ([[NSColorList alloc] initWithName:@"System"]);
  for (size_t i = 0; i < sizeof (colors) / sizeof (colors[0]); i++)
    [list setColor:hex (colors[i].color) forKey:colors[i].name];
  return [list writeToFile:colorsFile];
}

int
main (int argc, const char *argv[])
{
  CREATE_AUTORELEASE_POOL (pool);
  [NSApplication sharedApplication];
  /* Dark, the default: a cool, blue-tinted dark grey with the cyan accent. */
  struct palette dark = {
    .black = 0x000000, .page = 0x0b0c10, .plane = 0x15171c, .row = 0x17191f,
    .line = 0x23262e, .control = 0x23262e, .border = 0x3a3f4b, .title = 0x111318,
    .dim = 0x6b6f7c, .label = 0x9a9daa, .text = 0xe3e5ea, .accent = 0x00d4ff,
    .selection = 0x1b4a63, .selectedText = 0xffffff, .frameText = 0xe9eaef,
    .tip = 0x1a1d24, .secondarySelection = 0x2c3038,
  };
  /* Light (NBAppearance light): the same cool greys, light, with a deeper
     cyan that reads on white, and a light selection under dark text. */
  struct palette light = {
    .black = 0x8a8f9b, .page = 0xffffff, .plane = 0xf4f4f6, .row = 0xeceef1,
    .line = 0xdcdee3, .control = 0xffffff, .border = 0xc3c6ce, .title = 0xe8e9ed,
    .dim = 0x9a9ea8, .label = 0x6b6f7a, .text = 0x1d1f24, .accent = 0x00b4dc,
    .selection = 0xb6e3f2, .selectedText = 0x1d1f24, .frameText = 0x1d1f24,
    .tip = 0xffffff, .secondarySelection = 0xe2e4e9,
  };
  BOOL ok = write_lists (&dark, @"ThemeColors.clr");
  ok = write_lists (&light, @"ThemeColorsLight.clr") && ok;
  NSColorList *extra = AUTORELEASE ([[NSColorList alloc] initWithName:@"ThemeExtra"]);
  [extra setColor:hex (dark.selection) forKey:@"highlightedTableRowBackgroundColor"];
  [extra setColor:hex (dark.text) forKey:@"highlightedTableRowTextColor"];
  ok = [extra writeToFile:@"ThemeExtraColors.clr"] && ok;
  RELEASE (pool);
  return ok ? 0 : 1;
}

/*
 * NBHelpMenu.h: every app's Help menu, as on macOS.
 *
 * Copyright (c) 2026, Joseph Maloney
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef NB_HELP_MENU_H
#define NB_HELP_MENU_H

#import <AppKit/AppKit.h>

@interface NBHelpMenu : NSObject
/* Puts the search field, the app's book, NextBSD Help and Keyboard
   Shortcuts at the top of the main menu's Help menu (making one if the
   app has none). Safe to call again: it replaces what it put there. */
+ (void) organizeMainMenu: (NSMenu *)menu horizontal: (BOOL)horizontal;
/* Draws the search item as a field; NO for any other item. */
+ (BOOL) drawItemCell: (NSMenuItemCell *)cell
            withFrame: (NSRect)frame
          highlighted: (BOOL)highlighted
                field: (NSColor *)field
               border: (NSColor *)border;
@end

#endif

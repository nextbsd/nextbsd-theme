/*
 * NBDesktopSettings.h: how NextBSD reads a desktop setting.
 *
 * Copyright (c) 2026, Joseph Maloney
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * A desktop setting (Dock position, window mode, menu style, minimize
 * style) is resolved in this order:
 *
 *   1. the user's choice: the key in the user's defaults, normally
 *      NSGlobalDomain, written by Workspace Preferences. No value means
 *      "Use theme default";
 *   2. the active GNUstep theme's default: the same key at the top level
 *      of the theme bundle's Info.plist ([[GSTheme theme] infoDictionary]);
 *   3. the built-in default.
 *
 * A value that isn't one of the allowed ones is skipped, so a typo
 * falls through to the next level instead of breaking anything.
 *
 * This header is the reference implementation. It isn't installed; the
 * NextBSD backend (libs-back) and Workspace each carry a copy of the
 * function so they don't depend on the theme being built first. Keep
 * them in step with this file.
 */

#ifndef NB_DESKTOP_SETTINGS_H
#define NB_DESKTOP_SETTINGS_H

#import <Foundation/Foundation.h>
#import <GNUstepGUI/GSTheme.h>

#define NBDockPositionKey   @"NBDockPosition"   /* right left top bottom */
#define NBWindowModeKey     @"NBWindowMode"     /* stacking tiling */
#define NBMenuStyleKey      @"NBMenuStyle"      /* nextstep inwindow macmenubar */
#define NBMinimizeStyleKey  @"NBMinimizeStyle"  /* nextstep previews dock */

/* Posted (distributed, object nil) after a desktop setting changes; the
   userInfo has the "key" that changed. */
#define NBDesktopSettingsChangedNotification \
  @"org.nextbsd.DesktopSettingsChanged"

static inline NSString *
NBDesktopSettingValid(id value, NSArray *allowed)
{
  if ([value isKindOfClass: [NSString class]]
      && [allowed containsObject: value])
    return value;
  return nil;
}

/* The theme's default alone (levels 2 and 3), for "Use theme default". */
static inline NSString *
NBDesktopThemeDefault(NSString *key, NSArray *allowed, NSString *builtin)
{
  NSString *value;

  value = NBDesktopSettingValid(
    [[[GSTheme theme] infoDictionary] objectForKey: key], allowed);
  return value != nil ? value : builtin;
}

/* The effective value (levels 1, 2 and 3). */
static inline NSString *
NBDesktopSetting(NSString *key, NSArray *allowed, NSString *builtin)
{
  NSString *value;

  value = NBDesktopSettingValid(
    [[NSUserDefaults standardUserDefaults] objectForKey: key], allowed);
  return value != nil ? value : NBDesktopThemeDefault(key, allowed, builtin);
}

#endif

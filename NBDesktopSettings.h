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
 * The Dock position and the menu style are kept per window mode
 * (nextbsd-theme#8): stacking and tiling each have their own. For them,
 * in the current window mode (NBWindowMode, looked up as above):
 *
 *   1. the user's choice for the mode: NBModeSettings = { stacking =
 *      {...}; tiling = {...}; } in the user's defaults. In stacking, a
 *      plain user key (written before settings were kept per mode)
 *      counts as the user's stacking choice;
 *   2. the theme's default for the mode: NBModeDefaults = { stacking =
 *      {...}; tiling = {...}; } in its Info.plist;
 *   3. the theme's plain key, for themes without NBModeDefaults;
 *   4. the built-in default.
 *
 * A value that isn't one of the allowed ones is skipped, so a typo
 * falls through to the next level instead of breaking anything.
 *
 * This header is the reference implementation. It isn't installed; the
 * NextBSD backend (libs-back), the Dock and Workspace each carry a copy
 * of the lookup so they don't depend on the theme being built first.
 * Keep them in step with this file.
 */

#ifndef NB_DESKTOP_SETTINGS_H
#define NB_DESKTOP_SETTINGS_H

#import <Foundation/Foundation.h>
#import <GNUstepGUI/GSTheme.h>

#define NBDockPositionKey   @"NBDockPosition"   /* right left top bottom */
#define NBWindowModeKey     @"NBWindowMode"     /* stacking tiling */
#define NBMenuStyleKey      @"NBMenuStyle"      /* nextstep inwindow macmenubar */
#define NBMinimizeStyleKey  @"NBMinimizeStyle"  /* nextstep previews dock */

/* The per-mode dictionaries: the user's (defaults) and the theme's
   (Info.plist), each { stacking = {...}; tiling = {...}; }. */
#define NBModeSettingsKey   @"NBModeSettings"
#define NBModeDefaultsKey   @"NBModeDefaults"

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

/* Is the setting kept per window mode? */
static inline BOOL
NBDesktopSettingIsPerMode(NSString *key)
{
  return [key isEqual: NBDockPositionKey] || [key isEqual: NBMenuStyleKey];
}

/* modes[mode][key], when modes and modes[mode] are dictionaries. */
static inline id
NBDesktopModeValue(id modes, NSString *mode, NSString *key)
{
  id entry;

  if (![modes isKindOfClass: [NSDictionary class]])
    return nil;
  entry = [modes objectForKey: mode];
  if (![entry isKindOfClass: [NSDictionary class]])
    return nil;
  return [entry objectForKey: key];
}

/* The theme's default for `mode` (levels 2, 3 and 4 above; mode is
   ignored for settings not kept per mode). */
static inline NSString *
NBDesktopThemeDefaultForMode(NSString *key, NSString *mode,
			     NSArray *allowed, NSString *builtin)
{
  NSDictionary *info = [[GSTheme theme] infoDictionary];
  NSString *value = nil;

  if (NBDesktopSettingIsPerMode(key))
    value = NBDesktopSettingValid(
      NBDesktopModeValue([info objectForKey: NBModeDefaultsKey], mode, key),
      allowed);
  if (value == nil)
    value = NBDesktopSettingValid([info objectForKey: key], allowed);
  return value != nil ? value : builtin;
}

/* The user's own choice for `mode`, or nil for "Use theme default". */
static inline NSString *
NBDesktopUserSettingForMode(NSString *key, NSString *mode, NSArray *allowed)
{
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
  NSString *value;

  if (!NBDesktopSettingIsPerMode(key))
    return NBDesktopSettingValid([defs objectForKey: key], allowed);
  value = NBDesktopSettingValid(
    NBDesktopModeValue([defs objectForKey: NBModeSettingsKey], mode, key),
    allowed);
  if (value == nil && [mode isEqual: @"stacking"])
    value = NBDesktopSettingValid([defs objectForKey: key], allowed);
  return value;
}

/* The window mode in effect: stacking or tiling. */
static inline NSString *
NBDesktopWindowMode(void)
{
  NSArray *modes = [NSArray arrayWithObjects: @"stacking", @"tiling", nil];
  NSString *value;

  value = NBDesktopUserSettingForMode(NBWindowModeKey, nil, modes);
  return value != nil ? value
    : NBDesktopThemeDefaultForMode(NBWindowModeKey, nil, modes, @"stacking");
}

/* The theme's default alone, for "Use theme default". */
static inline NSString *
NBDesktopThemeDefault(NSString *key, NSArray *allowed, NSString *builtin)
{
  return NBDesktopThemeDefaultForMode(key, NBDesktopWindowMode(), allowed,
				      builtin);
}

/* The effective value in `mode`. */
static inline NSString *
NBDesktopSettingForMode(NSString *key, NSString *mode, NSArray *allowed,
			NSString *builtin)
{
  NSString *value = NBDesktopUserSettingForMode(key, mode, allowed);

  return value != nil ? value
    : NBDesktopThemeDefaultForMode(key, mode, allowed, builtin);
}

/* The effective value now. */
static inline NSString *
NBDesktopSetting(NSString *key, NSArray *allowed, NSString *builtin)
{
  return NBDesktopSettingForMode(key, NBDesktopWindowMode(), allowed,
				 builtin);
}

#endif

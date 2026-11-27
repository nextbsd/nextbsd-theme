/*
 * NBHelpMenu.m: every app's Help menu, as on macOS.
 *
 * Copyright (c) 2026, Joseph Maloney
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * The NextBSD theme puts these at the top of each app's Help menu:
 *
 *   Search                 a field: choosing it (or Command-?) opens the
 *                          help search in its place. Typing finds topics
 *                          in every help book and the app's own menu
 *                          commands; choosing a command shows it in its
 *                          menu, as macOS does
 *   <App> Help             the app's own book, when it has one: a .help
 *                          bundle in its Resources (<executable>.help, or
 *                          the one GSHelpContentsFile names)
 *   NextBSD Help           the system's book, which comes with Help.app
 *   Keyboard Shortcuts     its keyboard shortcuts topic
 *
 * and then the app's own items, without those that would show the same
 * book again. Help.app (nextbsd/apps-help) shows the books: a running
 * Help is asked over Distributed Objects (org.nextbsd.Help); otherwise
 * it is started with -NBHelpBook, -NBHelpTopic and -NBHelpSearch.
 *
 * Books are .help bundles of XLP files (see apps-help's README). The
 * search here reads only their topics' names, ids and keywords; Help's
 * own search reads the text too.
 */

#import "NBHelpMenu.h"
#import <GNUstepGUI/GSTheme.h>

/* What these items carry as their represented object, to find them. */
static NSString *const NBHelpItemTag = @"org.nextbsd.HelpMenuItem";
static NSString *const NBHelpSearchTag = @"org.nextbsd.HelpMenuSearch";

#define NBHelpServiceName @"org.nextbsd.Help"
#define NBHelpAppPath @"/System/Library/CoreServices/Help.app"

@protocol NBHelpService
- (oneway void) showBook: (NSString *)book
                   topic: (NSString *)topic
                  search: (NSString *)query;
@end

/* Show a book, a topic in it, or a search, in Help. */
static void
NBOpenHelp(NSString *book, NSString *topic, NSString *query)
{
  id proxy = nil;
  NSString *app;
  NSMutableArray *args;

  NS_DURING
    {
      NSConnection *c = [NSConnection
        connectionWithRegisteredName: NBHelpServiceName host: nil];

      [c setRequestTimeout: 5.0];
      [c setReplyTimeout: 5.0];
      proxy = [c rootProxy];
      if (proxy != nil)
        {
          [proxy setProtocolForProxy: @protocol(NBHelpService)];
          [(id <NBHelpService>)proxy showBook: book topic: topic
                                       search: query];
        }
    }
  NS_HANDLER
    proxy = nil;
  NS_ENDHANDLER
  if (proxy != nil)
    return;
  app = [[NSWorkspace sharedWorkspace] fullPathForApplication: @"Help"];
  if (app == nil)
    app = NBHelpAppPath;
  args = [NSMutableArray array];
  if ([book length] > 0)
    [args addObjectsFromArray: [NSArray arrayWithObjects: @"-NBHelpBook",
                                         book, nil]];
  if ([topic length] > 0)
    [args addObjectsFromArray: [NSArray arrayWithObjects: @"-NBHelpTopic",
                                         topic, nil]];
  if ([query length] > 0)
    [args addObjectsFromArray: [NSArray arrayWithObjects: @"-NBHelpSearch",
                                         query, nil]];
  NS_DURING
    {
      NSString *exe = [[NSBundle bundleWithPath: app] executablePath];

      if (exe != nil)
        [NSTask launchedTaskWithLaunchPath: exe arguments: args];
      else
        NSBeep();
    }
  NS_HANDLER
    NSBeep();
  NS_ENDHANDLER
}

/* The app's own book: <executable>.help in its Resources, or the
   .help that GSHelpContentsFile names, or nil. */
static NSString *
NBAppBook(void)
{
  NSBundle *mb = [NSBundle mainBundle];
  NSDictionary *info = [mb infoDictionary];
  NSString *name = [info objectForKey: @"GSHelpContentsFile"];

  if (![[name pathExtension] isEqual: @"help"])
    name = [[info objectForKey: @"NSExecutable"]
             stringByAppendingPathExtension: @"help"];
  if (name == nil)
    name = [[[NSProcessInfo processInfo] processName]
             stringByAppendingPathExtension: @"help"];
  return [mb pathForResource: [name stringByDeletingPathExtension]
                      ofType: @"help"];
}

static NSString *
NBAppName(void)
{
  NSString *n = [[[NSBundle mainBundle] localizedInfoDictionary]
                  objectForKey: @"ApplicationName"];

  return n != nil ? n : [[NSProcessInfo processInfo] processName];
}

/* ---- the help books' topics -------------------------------------------- */

static NSString *
NBDecode(NSString *s)
{
  NSMutableString *m;

  if ([s rangeOfString: @"&"].location == NSNotFound)
    return s;
  m = AUTORELEASE([s mutableCopy]);
  [m replaceOccurrencesOfString: @"&lt;" withString: @"<" options: 0
                          range: NSMakeRange(0, [m length])];
  [m replaceOccurrencesOfString: @"&gt;" withString: @">" options: 0
                          range: NSMakeRange(0, [m length])];
  [m replaceOccurrencesOfString: @"&quot;" withString: @"\"" options: 0
                          range: NSMakeRange(0, [m length])];
  [m replaceOccurrencesOfString: @"&apos;" withString: @"'" options: 0
                          range: NSMakeRange(0, [m length])];
  [m replaceOccurrencesOfString: @"&amp;" withString: @"&" options: 0
                          range: NSMakeRange(0, [m length])];
  return m;
}

/* A start tag's attributes. */
static NSDictionary *
NBTagAttributes(NSString *s)
{
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  NSScanner *sc = [NSScanner scannerWithString: s];
  NSCharacterSet *end = [NSCharacterSet characterSetWithCharactersInString:
                                          @"= \t\r\n/"];

  while (![sc isAtEnd])
    {
      NSString *key = nil, *value = @"", *q = nil;

      if (![sc scanUpToCharactersFromSet: end intoString: &key])
        {
          [sc setScanLocation: [sc scanLocation] + 1];
          continue;
        }
      if ([sc scanString: @"=" intoString: NULL]
          && ([sc scanString: @"\"" intoString: &q]
              || [sc scanString: @"'" intoString: &q]))
        {
          if (![sc scanUpToString: q intoString: &value])
            value = @"";
          [sc scanString: q intoString: NULL];
        }
      [d setObject: NBDecode(value) forKey: [key lowercaseString]];
    }
  return d;
}

/* The topics in one XLP file, and in the files it includes: each a
   dictionary of title, id and keywords. */
static void
NBScanXLP(NSString *book, NSString *file, NSMutableArray *topics,
          NSString **title, int depth)
{
  NSString *s = [NSString stringWithContentsOfFile:
                   [book stringByAppendingPathComponent: file]];
  NSUInteger pos = 0, n;

  if (s == nil || depth > 6)
    return;
  n = [s length];
  while (pos < n)
    {
      NSRange lt = [s rangeOfString: @"<" options: 0
                              range: NSMakeRange(pos, n - pos)];
      NSRange gt;
      NSString *tag, *name;
      NSRange sp;

      if (lt.location == NSNotFound)
        break;
      gt = [s rangeOfString: @">" options: 0
                      range: NSMakeRange(lt.location, n - lt.location)];
      if (gt.location == NSNotFound)
        break;
      tag = [s substringWithRange: NSMakeRange(lt.location + 1,
                                               gt.location - lt.location - 1)];
      pos = NSMaxRange(gt);
      sp = [tag rangeOfCharacterFromSet:
                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      name = [[(sp.location == NSNotFound ? tag
                : [tag substringToIndex: sp.location]) lowercaseString]
               stringByTrimmingCharactersInSet:
                 [NSCharacterSet characterSetWithCharactersInString: @"/"]];
      if ([name isEqual: @"title"] && title != NULL && *title == nil)
        {
          NSRange close = [s rangeOfString: @"</title>"
                                   options: NSCaseInsensitiveSearch
                                     range: NSMakeRange(pos, n - pos)];

          if (close.location != NSNotFound)
            *title = [[s substringWithRange:
                         NSMakeRange(pos, close.location - pos)]
                       stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
      else if ([name isEqual: @"part"] || [name isEqual: @"chapter"]
               || [name isEqual: @"section"] || [name isEqual: @"plain"]
               || [name isEqual: @"topic"])
        {
          NSDictionary *a = NBTagAttributes(sp.location == NSNotFound ? @""
                              : [tag substringFromIndex: sp.location]);
          NSString *t = [a objectForKey: @"name"];

          if (t != nil)
            [topics addObject: [NSDictionary dictionaryWithObjectsAndKeys:
              t, @"title",
              [a objectForKey: @"id"] ? [a objectForKey: @"id"] : t, @"id",
              [a objectForKey: @"keywords"] ? [a objectForKey: @"keywords"]
                                            : @"", @"keywords", nil]];
          if ([a objectForKey: @"src"] != nil)
            NBScanXLP(book, [a objectForKey: @"src"], topics, NULL, depth + 1);
        }
    }
}

/* Every book: { name, title, path, topics }, Help's own (NextBSD Help)
   first, then each app's, as Help lists them. */
static NSArray *
NBHelpBooks(void)
{
  NSMutableArray *books = [NSMutableArray array];
  NSMutableSet *seen = [NSMutableSet set];
  NSMutableArray *bundles = [NSMutableArray array];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableArray *dirs = [NSMutableArray arrayWithObjects:
    @"/System/Library/CoreServices", @"/System/Applications", nil];
  NSString *help = [[NSWorkspace sharedWorkspace]
                     fullPathForApplication: @"Help"];
  NSEnumerator *e;
  NSString *d;
  NSBundle *b;

  if (help == nil)
    help = NBHelpAppPath;
  if ((b = [NSBundle bundleWithPath: help]) != nil)
    [bundles addObject: b];
  [dirs addObjectsFromArray: NSSearchPathForDirectoriesInDomains(
    NSApplicationDirectory, NSAllDomainsMask, YES)];
  e = [dirs objectEnumerator];
  while ((d = [e nextObject]) != nil)
    {
      NSEnumerator *ae = [[[fm directoryContentsAtPath: d]
                            sortedArrayUsingSelector:
                              @selector(caseInsensitiveCompare:)]
                           objectEnumerator];
      NSString *a;

      while ((a = [ae nextObject]) != nil)
        if ([[a pathExtension] isEqual: @"app"]
            && (b = [NSBundle bundleWithPath:
                       [d stringByAppendingPathComponent: a]]) != nil)
          [bundles addObject: b];
    }
  e = [bundles objectEnumerator];
  while ((b = [e nextObject]) != nil)
    {
      NSEnumerator *pe = [[b pathsForResourcesOfType: @"help" inDirectory: nil]
                           objectEnumerator];
      NSString *p;

      while ((p = [pe nextObject]) != nil)
        {
          NSString *name = [[p lastPathComponent] stringByDeletingPathExtension];
          NSMutableArray *topics = [NSMutableArray array];
          NSString *title = nil;

          if ([seen containsObject: name])
            continue;
          [seen addObject: name];
          NBScanXLP(p, @"main.xlp", topics, &title, 0);
          if (title == nil)
            title = [NSString stringWithFormat: @"%@ Help", name];
          [books addObject: [NSDictionary dictionaryWithObjectsAndKeys:
            name, @"name", title, @"title", p, @"path", topics, @"topics",
            nil]];
        }
    }
  return books;
}

/* ---- the search panel ---------------------------------------------------- */

/* A row: a topic (book, topic id), a menu command (the item), a plain
   item (Workspace Help...), or "show all results in Help". */
enum { NBRowTopic, NBRowMenu, NBRowItem, NBRowAll };

@interface NBHelpPanel : NSPanel
@end

@implementation NBHelpPanel
- (BOOL) canBecomeKeyWindow { return YES; }
- (BOOL) canBecomeMainWindow { return NO; }
@end

@interface NBHelpSearchView : NSView
{
  NSTextField *field;
  NSMutableArray *results;      /* {kind, title, detail, target} */
  NSMutableArray *items;        /* the plain items below */
  NSArray *books;
  NSInteger selected;
  NSArray *menuCommands;
}
+ (NBHelpSearchView *) shared;
- (void) showAt: (NSPoint)topLeft width: (CGFloat)width;
@end

static const CGFloat NBPad = 8, NBFieldH = 30, NBResultH = 30, NBItemH = 28;

@implementation NBHelpSearchView

+ (NBHelpSearchView *) shared
{
  static NBHelpSearchView *shared = nil;

  if (shared == nil)
    {
      NBHelpPanel *panel = [[NBHelpPanel alloc]
        initWithContentRect: NSMakeRect(0, 0, 420, 200)
                  styleMask: NSBorderlessWindowMask
                    backing: NSBackingStoreBuffered
                      defer: NO];

      /* Above the menus, but not at a menu's level: the NextBSD backend
         never makes a window at a menu level key, and this one takes
         typing. */
      [panel setLevel: NSModalPanelWindowLevel];
      [panel setHidesOnDeactivate: YES];
      [panel setReleasedWhenClosed: NO];
      [panel setAcceptsMouseMovedEvents: YES];
      shared = [[NBHelpSearchView alloc]
                 initWithFrame: NSMakeRect(0, 0, 420, 200)];
      [panel setContentView: shared];
      [panel setDelegate: (id)shared];
    }
  return shared;
}

- (id) initWithFrame: (NSRect)f
{
  if ((self = [super initWithFrame: f]) != nil)
    {
      field = [[NSTextField alloc] initWithFrame:
        NSMakeRect(NBPad, NBPad, NSWidth(f) - 2 * NBPad, NBFieldH)];
      [field setDelegate: (id)self];
      [field setTarget: self];
      [field setAction: @selector(choose:)];
      [[field cell] setPlaceholderString: @"Search"];
      [[field cell] setScrollable: YES];
      [field setFont: [NSFont systemFontOfSize: 13]];
      [self addSubview: field];
      results = [[NSMutableArray alloc] init];
      items = [[NSMutableArray alloc] init];
      selected = -1;
    }
  return self;
}

- (BOOL) isFlipped
{
  return YES;
}

- (NSUInteger) rowCount
{
  return [results count] + [items count];
}

- (NSArray *) rowAtIndex: (NSInteger)i
{
  if (i < 0)
    return nil;
  if ((NSUInteger)i < [results count])
    return [results objectAtIndex: i];
  i -= [results count];
  return (NSUInteger)i < [items count] ? [items objectAtIndex: i] : nil;
}

- (NSRect) rectOfRow: (NSInteger)i
{
  CGFloat y = NBPad + NBFieldH + NBPad;

  if ((NSUInteger)i < [results count])
    return NSMakeRect(NBPad, y + i * NBResultH,
                      NSWidth([self bounds]) - 2 * NBPad, NBResultH);
  y += [results count] * NBResultH;
  if ([results count] > 0)
    y += 17;
  i -= [results count];
  return NSMakeRect(NBPad, y + i * NBItemH,
                    NSWidth([self bounds]) - 2 * NBPad, NBItemH);
}

- (CGFloat) heightNeeded
{
  NSInteger n = [self rowCount];

  if (n == 0)
    return NBPad * 2 + NBFieldH;
  return NSMaxY([self rectOfRow: n - 1]) + NBPad;
}

/* Every menu command: { "Parent › Title", the item }. */
static void
NBCollectCommands(NSMenu *menu, NSString *path, NSMutableArray *out)
{
  NSEnumerator *e = [[menu itemArray] objectEnumerator];
  NSMenuItem *it;

  while ((it = [e nextObject]) != nil)
    {
      NSString *title = [it title];

      if ([it isSeparatorItem] || [title length] == 0
          || [[it representedObject] isEqual: NBHelpItemTag]
          || [[it representedObject] isEqual: NBHelpSearchTag])
        continue;
      if ([it submenu] != nil)
        NBCollectCommands([it submenu], path == nil ? title
                          : [NSString stringWithFormat: @"%@ › %@",
                                      path, title], out);
      else if ([it action] != NULL)
        [out addObject: [NSArray arrayWithObjects:
          path == nil ? title : [NSString stringWithFormat: @"%@ › %@",
                                          path, title], it, nil]];
    }
}

- (void) setItems
{
  NSString *book = NBAppBook();

  [items removeAllObjects];
  if (book != nil)
    [items addObject: [NSArray arrayWithObjects:
      [NSNumber numberWithInt: NBRowItem],
      [NSString stringWithFormat: @"%@ Help", NBAppName()], @"",
      [NSArray arrayWithObjects: book, @"", nil], nil]];
  [items addObject: [NSArray arrayWithObjects:
    [NSNumber numberWithInt: NBRowItem], @"NextBSD Help", @"",
    [NSArray arrayWithObjects: @"NextBSD", @"", nil], nil]];
  [items addObject: [NSArray arrayWithObjects:
    [NSNumber numberWithInt: NBRowItem], @"Keyboard Shortcuts", @"",
    [NSArray arrayWithObjects: @"NextBSD", @"keyboard-shortcuts", nil], nil]];
}

static BOOL
NBMatches(NSString *text, NSArray *words)
{
  NSEnumerator *e = [words objectEnumerator];
  NSString *w;

  while ((w = [e nextObject]) != nil)
    if ([text rangeOfString: w options: NSCaseInsensitiveSearch].location
        == NSNotFound)
      return NO;
  return YES;
}

- (void) update
{
  NSString *q = [[field stringValue] stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSMutableArray *words = [NSMutableArray array];
  NSEnumerator *e;
  NSString *w;
  NSUInteger topics = 0, commands = 0;
  NSRect f;

  [results removeAllObjects];
  e = [[q componentsSeparatedByString: @" "] objectEnumerator];
  while ((w = [e nextObject]) != nil)
    if ([w length] > 0)
      [words addObject: w];
  if ([words count] > 0)
    {
      NSEnumerator *be = [books objectEnumerator];
      NSDictionary *book;
      NSArray *cmd;

      /* Topics whose title has the words first, then those whose
         keywords have them. */
      while ((book = [be nextObject]) != nil && topics < 6)
        {
          NSEnumerator *te = [[book objectForKey: @"topics"] objectEnumerator];
          NSDictionary *t;

          while ((t = [te nextObject]) != nil && topics < 6)
            if (NBMatches([t objectForKey: @"title"], words))
              {
                [results addObject: [NSArray arrayWithObjects:
                  [NSNumber numberWithInt: NBRowTopic],
                  [t objectForKey: @"title"], [book objectForKey: @"title"],
                  [NSArray arrayWithObjects: [book objectForKey: @"path"],
                           [t objectForKey: @"id"], nil], nil]];
                topics++;
              }
        }
      be = [books objectEnumerator];
      while ((book = [be nextObject]) != nil && topics < 6)
        {
          NSEnumerator *te = [[book objectForKey: @"topics"] objectEnumerator];
          NSDictionary *t;

          while ((t = [te nextObject]) != nil && topics < 6)
            if (!NBMatches([t objectForKey: @"title"], words)
                && NBMatches([t objectForKey: @"keywords"], words))
              {
                [results addObject: [NSArray arrayWithObjects:
                  [NSNumber numberWithInt: NBRowTopic],
                  [t objectForKey: @"title"], [book objectForKey: @"title"],
                  [NSArray arrayWithObjects: [book objectForKey: @"path"],
                           [t objectForKey: @"id"], nil], nil]];
                topics++;
              }
        }
      e = [menuCommands objectEnumerator];
      while ((cmd = [e nextObject]) != nil && commands < 4)
        if (NBMatches([cmd objectAtIndex: 0], words))
          {
            [results addObject: [NSArray arrayWithObjects:
              [NSNumber numberWithInt: NBRowMenu], [cmd objectAtIndex: 0],
              @"", [cmd objectAtIndex: 1], nil]];
            commands++;
          }
      [results addObject: [NSArray arrayWithObjects:
        [NSNumber numberWithInt: NBRowAll],
        [NSString stringWithFormat: @"Show all results for “%@”", q],
        @"", q, nil]];
    }
  selected = [results count] > 1 ? 0 : -1;
  f = [[self window] frame];
  {
    CGFloat h = [self heightNeeded];

    f.origin.y = NSMaxY(f) - h;
    f.size.height = h;
  }
  [[self window] setFrame: f display: NO];
  [self setNeedsDisplay: YES];
}

- (void) showAt: (NSPoint)topLeft width: (CGFloat)width
{
  NSWindow *w = [self window];
  NSMutableArray *cmds = [NSMutableArray array];

  ASSIGN(books, NBHelpBooks());
  NBCollectCommands([NSApp mainMenu], nil, cmds);
  ASSIGN(menuCommands, cmds);
  [self setItems];
  [field setStringValue: @""];
  [field setFrame: NSMakeRect(NBPad, NBPad, width - 2 * NBPad, NBFieldH)];
  [w setFrame: NSMakeRect(topLeft.x, topLeft.y - 100, width, 100)
      display: NO];
  [self update];
  [w makeKeyAndOrderFront: nil];
  [w makeFirstResponder: field];
}

- (void) close
{
  [[self window] orderOut: nil];
}

- (void) windowDidResignKey: (NSNotification *)n
{
  [self close];
}

/* Choosing a menu command shows it in its menu: the menus open down
   to it, with it highlighted, until the next click or key; a click on
   it, or Return, chooses it. */
- (void) showCommand: (NSMenuItem *)item
{
  NSMutableArray *chain = [NSMutableArray array];
  NSMenu *m;
  NSMenuItem *it = item;
  NSUInteger i;
  NSMenuView *last = nil;
  NSInteger lastIndex = -1;
  NSEvent *e;
  BOOL choose = NO;

  /* The menus from the main menu down to the item's. */
  for (m = [item menu]; m != nil; m = [m supermenu])
    {
      [chain insertObject: [NSArray arrayWithObjects: m,
        [NSNumber numberWithInteger: [m indexOfItem: it]], nil] atIndex: 0];
      it = [[m supermenu] itemAtIndex: [[m supermenu] indexOfItemWithSubmenu: m]];
    }
  for (i = 0; i < [chain count]; i++)
    {
      NSMenu *menu = [[chain objectAtIndex: i] objectAtIndex: 0];
      NSInteger index = [[[chain objectAtIndex: i] objectAtIndex: 1]
                          integerValue];
      NSMenuView *v = [menu menuRepresentation];

      if (![v isKindOfClass: [NSMenuView class]] || index < 0)
        return;
      if (i == 0)
        [[v window] orderFront: nil];
      [v setHighlightedItemIndex: index];
      if (i + 1 < [chain count])
        [v attachSubmenuForItemAtIndex: index];
      [v display];
      last = v;
      lastIndex = index;
    }
  /* Wait for the next click or key. */
  e = [NSApp nextEventMatchingMask: NSLeftMouseDownMask | NSRightMouseDownMask
                                    | NSKeyDownMask
                         untilDate: [NSDate distantFuture]
                            inMode: NSEventTrackingRunLoopMode
                           dequeue: YES];
  if ([e type] == NSKeyDown)
    choose = [[e characters] isEqual: @"\r"] || [[e characters] isEqual: @"\n"]
      || [[e characters] isEqual: @"\003"];
  else if ([e type] == NSLeftMouseDown && [e window] == [last window])
    {
      NSPoint p = [last convertPoint: [e locationInWindow] fromView: nil];

      choose = [last indexOfItemAtPoint: p] == lastIndex;
    }
  /* Close them again. */
  for (i = [chain count]; i > 0; i--)
    {
      NSMenu *menu = [[chain objectAtIndex: i - 1] objectAtIndex: 0];
      NSMenuView *v = [menu menuRepresentation];

      [v setHighlightedItemIndex: -1];
      if (i < [chain count])
        [v detachSubmenu];
      [v display];
    }
  if (choose)
    [[item menu] performActionForItemAtIndex: [[item menu] indexOfItem: item]];
}

- (void) chooseRow: (NSInteger)i
{
  NSArray *row = [self rowAtIndex: i];
  int kind;
  id target;

  if (row == nil)
    return;
  kind = [[row objectAtIndex: 0] intValue];
  target = [row objectAtIndex: 3];
  [self close];
  if (kind == NBRowMenu)
    [self showCommand: target];
  else if (kind == NBRowAll)
    NBOpenHelp(nil, nil, target);
  else
    NBOpenHelp([target objectAtIndex: 0], [target objectAtIndex: 1], nil);
}

- (void) choose: (id)sender
{
  NSString *q = [[field stringValue] stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceCharacterSet]];

  if (selected >= 0)
    [self chooseRow: selected];
  else if ([q length] > 0)
    {
      [self close];
      NBOpenHelp(nil, nil, q);
    }
}

- (void) controlTextDidChange: (NSNotification *)n
{
  [self update];
}

- (BOOL) control: (NSControl *)c textView: (NSTextView *)tv
    doCommandBySelector: (SEL)cmd
{
  NSInteger n = [self rowCount];

  if (sel_isEqual(cmd, @selector(moveDown:)) && n > 0)
    selected = selected + 1 >= n ? 0 : selected + 1;
  else if (sel_isEqual(cmd, @selector(moveUp:)) && n > 0)
    selected = selected <= 0 ? n - 1 : selected - 1;
  else if (sel_isEqual(cmd, @selector(cancelOperation:))
           || sel_isEqual(cmd, @selector(cancel:)))
    {
      [self close];
      return YES;
    }
  else
    return NO;
  [self setNeedsDisplay: YES];
  return YES;
}

- (void) keyDown: (NSEvent *)e
{
  if ([[e characters] isEqual: @"\033"])
    [self close];
  else
    [super keyDown: e];
}

- (NSInteger) rowAtPoint: (NSPoint)p
{
  NSInteger i;

  for (i = 0; i < (NSInteger)[self rowCount]; i++)
    if (NSPointInRect(p, [self rectOfRow: i]))
      return i;
  return -1;
}

- (void) mouseMoved: (NSEvent *)e
{
  NSInteger i = [self rowAtPoint:
    [self convertPoint: [e locationInWindow] fromView: nil]];

  if (i >= 0 && i != selected)
    {
      selected = i;
      [self setNeedsDisplay: YES];
    }
}

- (void) mouseUp: (NSEvent *)e
{
  NSInteger i = [self rowAtPoint:
    [self convertPoint: [e locationInWindow] fromView: nil]];

  if (i >= 0)
    [self chooseRow: i];
}

- (void) mouseDown: (NSEvent *)e
{
}

- (void) drawRect: (NSRect)r
{
  GSTheme *theme = [GSTheme theme];
  NSRect b = [self bounds];
  NSColor *text = [NSColor controlTextColor];
  NSColor *dim = [NSColor disabledControlTextColor];
  NSColor *accent = [NSColor selectedMenuItemColor];
  NSColor *onAccent = [NSColor selectedMenuItemTextColor];
  NSInteger i, n = [self rowCount];

  [[theme menuBackgroundColor] set];
  NSRectFill(r);
  [[theme menuBorderColor] set];
  NSFrameRect(b);
  if ([results count] > 0)
    {
      CGFloat y = NSMaxY([self rectOfRow: [results count] - 1]) + 8;

      [[theme menuBorderColor] set];
      NSRectFill(NSMakeRect(NBPad + 4, y, NSWidth(b) - 2 * NBPad - 8, 1));
    }
  for (i = 0; i < n; i++)
    {
      NSArray *row = [self rowAtIndex: i];
      int kind = [[row objectAtIndex: 0] intValue];
      NSRect rr = [self rectOfRow: i];
      BOOL sel = (i == selected);
      NSColor *fg = sel ? onAccent : text;
      NSDictionary *ta = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSFont systemFontOfSize: 13], NSFontAttributeName,
        fg, NSForegroundColorAttributeName, nil];
      CGFloat x = NSMinX(rr) + 10;
      NSString *title = [row objectAtIndex: 1];
      NSString *detail = [row objectAtIndex: 2];

      if (sel)
        {
          [accent set];
          [[NSBezierPath bezierPathWithRoundedRect: rr xRadius: 6 yRadius: 6]
            fill];
        }
      if (kind == NBRowTopic || kind == NBRowMenu)
        {
          NSDictionary *ka = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont boldSystemFontOfSize: 9], NSFontAttributeName,
            sel ? onAccent : dim, NSForegroundColorAttributeName,
            [NSNumber numberWithFloat: 0.6], NSKernAttributeName, nil];

          [(kind == NBRowTopic ? @"TOPIC" : @"MENU")
            drawAtPoint: NSMakePoint(x, NSMinY(rr) + 9) withAttributes: ka];
          x += 46;
        }
      if ([detail length] > 0)
        {
          NSDictionary *da = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont systemFontOfSize: 11], NSFontAttributeName,
            sel ? onAccent : dim, NSForegroundColorAttributeName, nil];
          NSSize ds = [detail sizeWithAttributes: da];

          [detail drawAtPoint: NSMakePoint(NSMaxX(rr) - 10 - ds.width,
                                           NSMinY(rr) + floor((NSHeight(rr) - ds.height) / 2))
               withAttributes: da];
        }
      [title drawAtPoint: NSMakePoint(x, NSMinY(rr) + floor((NSHeight(rr) - 16) / 2))
          withAttributes: ta];
    }
}

@end

/* ---- the menu ---------------------------------------------------------- */

@implementation NBHelpMenu

+ (NBHelpMenu *) target
{
  static NBHelpMenu *t = nil;

  if (t == nil)
    t = [NBHelpMenu new];
  return t;
}

/* The main menu's Help item. In a menu bar the app's own menu (after
   the NextBSD menu) is called after the app, which in Help.app is Help
   too: it isn't the Help menu. */
static NSInteger
NBHelpIndex(NSMenu *menu, BOOL horizontal)
{
  NSInteger first = horizontal
    ? [menu indexOfItemWithTitle: NBAppName()] + 1 : 0;
  NSInteger i;

  for (i = [menu numberOfItems] - 1; i >= first; i--)
    if ([[[menu itemAtIndex: i] title] isEqual: @"Help"])
      return i;
  return -1;
}

/* Where the search opens: in place of the Help menu. */
+ (NSPoint) searchOrigin: (CGFloat *)width
{
  NSMenu *main = [NSApp mainMenu];
  NSMenuView *mv0 = [main menuRepresentation];
  NSInteger i = NBHelpIndex(main, [mv0 isKindOfClass: [NSMenuView class]]
                                  && [mv0 isHorizontal]);
  NSMenu *help = i >= 0 ? [[main itemAtIndex: i] submenu] : nil;
  NSMenuView *hv = [help menuRepresentation];
  NSMenuView *mv = [main menuRepresentation];
  NSRect screen = [[NSScreen mainScreen] frame];

  *width = 420;
  if ([hv isKindOfClass: [NSMenuView class]] && [[hv window] isVisible])
    {
      NSRect f = [[hv window] frame];

      *width = MAX(420, NSWidth(f));
      return NSMakePoint(NSMinX(f), NSMaxY(f));
    }
  if ([mv isKindOfClass: [NSMenuView class]] && i >= 0)
    {
      NSRect item = [mv rectOfItemAtIndex: i];
      NSPoint p;

      item = [mv convertRect: item toView: nil];
      p = [[mv window] convertBaseToScreen: item.origin];
      if ([mv isHorizontal])
        return NSMakePoint(p.x, p.y);
      return NSMakePoint(p.x + NSWidth(item) + 1, p.y + NSHeight(item));
    }
  return NSMakePoint(NSMidX(screen) - 210, NSMaxY(screen) - 30);
}

- (void) searchHelp: (id)sender
{
  CGFloat width;
  NSPoint p = [NBHelpMenu searchOrigin: &width];

  [[NBHelpSearchView shared] showAt: p width: width];
}

- (void) appHelp: (id)sender
{
  NBOpenHelp(NBAppBook(), nil, nil);
}

- (void) nextbsdHelp: (id)sender
{
  NBOpenHelp(@"NextBSD", nil, nil);
}

- (void) keyboardShortcuts: (id)sender
{
  NBOpenHelp(@"NextBSD", @"keyboard-shortcuts", nil);
}

static NSImage *
NBMagnifier(void)
{
  static NSImage *image = nil;

  if (image == nil)
    {
      NSBezierPath *p = [NSBezierPath bezierPath];

      image = [[NSImage alloc] initWithSize: NSMakeSize(14, 14)];
      [image lockFocus];
      [[NSColor disabledControlTextColor] set];
      [p appendBezierPathWithOvalInRect: NSMakeRect(1.5, 4.5, 8, 8)];
      [p moveToPoint: NSMakePoint(8.3, 5.7)];
      [p lineToPoint: NSMakePoint(12.5, 1.5)];
      [p setLineWidth: 1.6];
      [p setLineCapStyle: NSRoundLineCapStyle];
      [p stroke];
      [image unlockFocus];
    }
  return image;
}

static NSMenuItem *
NBItem(NSString *title, SEL action, NSString *key, id tag)
{
  NSMenuItem *it = AUTORELEASE([[NSMenuItem alloc] initWithTitle: title
                                                          action: action
                                                   keyEquivalent: key]);

  [it setTarget: [NBHelpMenu target]];
  [it setRepresentedObject: tag];
  return it;
}

+ (void) organizeMainMenu: (NSMenu *)menu horizontal: (BOOL)horizontal
{
  NSInteger i = NBHelpIndex(menu, horizontal);
  NSMenu *help;
  NSString *book = NBAppBook();
  NSString *bookTitle = [NSString stringWithFormat: @"%@ Help", NBAppName()];
  NSMenuItem *search;
  NSInteger at = 0;

  if ([[[NSProcessInfo processInfo] processName] isEqual: @"Help"])
    book = nil;
  if (i >= 0 && [[menu itemAtIndex: i] submenu] != nil)
    help = [[menu itemAtIndex: i] submenu];
  else
    {
      /* An app without a Help menu gets one: last in a menu bar, before
         Hide and Quit in a NeXT menu. */
      NSInteger where = [menu numberOfItems];
      NSInteger j;

      if (!horizontal)
        for (j = 0; j < [menu numberOfItems]; j++)
          {
            SEL a = [[menu itemAtIndex: j] action];

            if (sel_isEqual(a, @selector(hide:))
                || sel_isEqual(a, @selector(terminate:)))
              {
                where = j;
                break;
              }
          }
      help = AUTORELEASE([[NSMenu alloc] initWithTitle: @"Help"]);
      [[menu insertItemWithTitle: @"Help" action: NULL keyEquivalent: @""
                         atIndex: where] setSubmenu: help];
    }
  /* What was put here before, and the app's own items for the same. */
  for (i = [help numberOfItems] - 1; i >= 0; i--)
    {
      NSMenuItem *it = [help itemAtIndex: i];
      id tag = [it representedObject];

      if ([tag isEqual: NBHelpItemTag] || [tag isEqual: NBHelpSearchTag]
          || sel_isEqual([it action], @selector(showHelp:))
          || (book != nil && [[it title] isEqual: bookTitle]))
        [help removeItemAtIndex: i];
    }
  search = NBItem(@"Search", @selector(searchHelp:), @"?", NBHelpSearchTag);
  [search setImage: NBMagnifier()];
  [help insertItem: search atIndex: at++];
  if (book != nil)
    [help insertItem: NBItem(bookTitle, @selector(appHelp:), @"",
                             NBHelpItemTag) atIndex: at++];
  [help insertItem: NBItem(@"NextBSD Help", @selector(nextbsdHelp:), @"",
                           NBHelpItemTag) atIndex: at++];
  [help insertItem: NBItem(@"Keyboard Shortcuts",
                           @selector(keyboardShortcuts:), @"",
                           NBHelpItemTag) atIndex: at++];
  /* Help's own "NextBSD Help" is the same thing. */
  for (i = [help numberOfItems] - 1; i >= at; i--)
    if ([[[help itemAtIndex: i] title] isEqual: @"NextBSD Help"])
      [help removeItemAtIndex: i];
  if ([help numberOfItems] > at)
    {
      NSMenuItem *sep = (NSMenuItem *)[NSMenuItem separatorItem];

      [sep setRepresentedObject: NBHelpItemTag];
      [help insertItem: sep atIndex: at];
    }
}

+ (BOOL) drawItemCell: (NSMenuItemCell *)cell
            withFrame: (NSRect)frame
          highlighted: (BOOL)highlighted
                field: (NSColor *)field
               border: (NSColor *)border
{
  NSBezierPath *p;

  if (![[[cell menuItem] representedObject] isEqual: NBHelpSearchTag])
    return NO;
  if (highlighted)
    return NO;
  p = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(frame, 2.5, 1.5)
                                      xRadius: 6 yRadius: 6];
  [field set];
  [p fill];
  [border set];
  [p setLineWidth: 1];
  [p stroke];
  return YES;
}

@end

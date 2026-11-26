#import <AppKit/AppKit.h>
#import <AppKit/PSOperators.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>
#include <math.h>

@interface NextBSD : GSTheme
@end

/*
 * Miniwindow icons that fit (NeXT minimize style).
 *
 * GNUstep draws a miniwindow's icon at the image's own size, so a 64x64
 * app icon on a 64x64 miniwindow covers the title along the bottom. While
 * this theme is active, a wrapper around NSMiniWindowView's -setImage:
 * (libs-gui's private miniwindow content view) hands it a copy of any
 * image larger than three quarters of the miniwindow, scaled down to fit
 * in that square, and then calls libs-gui's own -setImage: with it. No
 * libs-gui code is copied here; the wrapper only resizes the image.
 *
 * Nothing happens if the class or the method isn't there, and the wrapper
 * is installed once however often the theme is activated.
 */

typedef void (*NBSetImageIMP)(id, SEL, NSImage *);

static NBSetImageIMP miniWindowSetImage = NULL;
static BOOL fitMiniwindowIcons = NO;
/* The Mac menu bar's opacity: see-through as macOS's, a little less,
   since nothing blurs what's behind it. */
static const CGFloat NBMenuBarOpacity = 0.8;

static NSImage *
NBFittedMiniwindowImage(NSView *view, NSImage *image)
{
  NSSize box = [view frame].size;
  NSSize size = [image size];
  CGFloat limit;
  CGFloat scale;
  NSImage *fitted;

  if (box.width < 1.0 || box.height < 1.0)
    box = NSMakeSize(64.0, 64.0);
  limit = floor(MIN(box.width, box.height) * 0.75);
  if (size.width <= limit && size.height <= limit)
    return image;
  if (size.width < 1.0 || size.height < 1.0)
    return image;

  scale = MIN(limit / size.width, limit / size.height);
  fitted = AUTORELEASE([image copy]);
  [fitted setScalesWhenResized: YES];
  [fitted setSize: NSMakeSize(floor(size.width * scale + 0.5),
                              floor(size.height * scale + 0.5))];
  return fitted;
}

static void
NBMiniWindowViewSetImage(id view, SEL cmd, NSImage *image)
{
  if (fitMiniwindowIcons && image != nil)
    image = NBFittedMiniwindowImage(view, image);
  miniWindowSetImage(view, cmd, image);
}

static void
NBInstallMiniwindowIconFit(void)
{
  Class cls;
  Method m;

  if (miniWindowSetImage != NULL)
    return;
  cls = NSClassFromString(@"NSMiniWindowView");
  if (cls == Nil)
    return;
  /* Only a method of the class itself, never an inherited one. */
  m = class_getInstanceMethod(cls, @selector(setImage:));
  if (m == NULL || class_getInstanceMethod(class_getSuperclass(cls),
                                           @selector(setImage:)) == m)
    return;
  miniWindowSetImage = (NBSetImageIMP)
    method_setImplementation(m, (IMP)NBMiniWindowViewSetImage);
}


/*
 * The redesign (nextbsd/nextbsd#708; mockups/desktop.html is the
 * reference): soft rounded controls with thin borders instead of NeXT
 * bevels, flat title bars that dim when the window isn't key, and the
 * cyan accent on the default button, checked boxes and focus.
 */
static NSColor *
NBHex(unsigned value)
{
  return [NSColor colorWithCalibratedRed: ((value >> 16) & 255) / 255.0
                                   green: ((value >> 8) & 255) / 255.0
                                    blue: (value & 255) / 255.0
                                   alpha: 1.0];
}

/*
 * The desktop settings this theme draws by, both in NSGlobalDomain and
 * set in Workspace Preferences, each with this theme's default (its
 * Info.plist) when the person hasn't chosen:
 *
 *   NBAppearance   dark (the default) or light
 *   NBWindowStyle  nextstep (the default): miniaturize at the left of
 *                  the title bar, close at the right, faint until the
 *                  pointer is over them; mac: traffic lights at the
 *                  left, close, minimize and zoom; tiling: minimize,
 *                  maximize and close at the right, as on Windows
 *
 * Both change at once in running apps (NBSettingsObserver below).
 */
static BOOL nbLight = NO;
static NSString *nbWindowStyle = @"nextstep";

/* The colours the theme draws with itself, for the appearance in use. */
static unsigned NBControl, NBControlPressed, NBControlBorder, NBField, NBFieldBorder;
static unsigned NBAccent, NBAccentText, NBTitle, NBTitleInactive, NBTitleText;
static unsigned NBTitleTextInactive, NBSeparator, NBWindowBorder, NBWindowBorderInactive;
static unsigned NBPlane, NBKnob, NBKnobPressed, NBHeaderPressed, NBHeaderText;
static unsigned NBMenu;

static void
NBApplyPalette(void)
{
  if (!nbLight)
    {
      NBControl = 0x23262e; NBControlPressed = 0x1a1c22; NBControlBorder = 0x3a3f4b;
      NBField = 0x0b0c10; NBFieldBorder = 0x2e323c; NBAccent = 0x00d4ff;
      NBAccentText = 0x04141a; NBTitle = 0x111318; NBTitleInactive = 0x0f1013;
      NBTitleText = 0xe9eaef; NBTitleTextInactive = 0x6b6f7c; NBSeparator = 0x23262e;
      NBWindowBorder = 0x333845; NBWindowBorderInactive = 0x262a32;
      NBPlane = 0x15171c; NBKnob = 0x3a3f4b; NBKnobPressed = 0x555b68;
      NBHeaderPressed = 0x1d2027; NBHeaderText = 0x9a9daa;
      NBMenu = 0x1a1d24;
    }
  else
    {
      NBControl = 0xffffff; NBControlPressed = 0xe6e7eb; NBControlBorder = 0xc3c6ce;
      NBField = 0xffffff; NBFieldBorder = 0xc3c6ce; NBAccent = 0x00b4dc;
      NBAccentText = 0x04141a; NBTitle = 0xe8e9ed; NBTitleInactive = 0xf2f2f4;
      NBTitleText = 0x1d1f24; NBTitleTextInactive = 0x9a9ea8; NBSeparator = 0xd3d5db;
      NBWindowBorder = 0xb4b8c1; NBWindowBorderInactive = 0xcdd0d6;
      NBPlane = 0xf4f4f6; NBKnob = 0xc3c6ce; NBKnobPressed = 0xa5a9b2;
      NBHeaderPressed = 0xe6e7eb; NBHeaderText = 0x6b6f7a;
      NBMenu = 0xffffff;
    }
}

/* A setting: the person's (NSGlobalDomain), else the theme's, else the
   built-in default, if it's one of the allowed values. */
static NSString *
NBSetting(NSDictionary *info, NSString *key, NSArray *allowed, NSString *builtin)
{
  id value = [[NSUserDefaults standardUserDefaults] objectForKey: key];

  if (![allowed containsObject: value])
    value = [info objectForKey: key];
  return [allowed containsObject: value] ? value : builtin;
}

static void
NBReadSettings(NSDictionary *info)
{
  nbLight = [NBSetting(info, @"NBAppearance",
    [NSArray arrayWithObjects: @"dark", @"light", nil], @"dark") isEqual: @"light"];
  ASSIGN(nbWindowStyle, NBSetting(info, @"NBWindowStyle",
    [NSArray arrayWithObjects: @"nextstep", @"mac", @"tiling", nil], @"nextstep"));
  NBApplyPalette();
}
static const CGFloat NBRadius = 5.0;
static const CGFloat NBTitleHeight = 26.0;

/* A rounded rectangle on the pixel grid, filled and outlined. */
static void
NBRoundRect(NSRect r, CGFloat radius, NSColor *fill, NSColor *stroke)
{
  NSBezierPath *path;

  r = NSInsetRect(r, 0.5, 0.5);
  if (NSWidth(r) < 1.0 || NSHeight(r) < 1.0)
    return;
  radius = MIN(radius, MIN(NSWidth(r), NSHeight(r)) / 2.0);
  path = [NSBezierPath bezierPath];
  [path appendBezierPathWithRoundedRect: r xRadius: radius yRadius: radius];
  if (fill != nil)
    {
      [fill set];
      [path fill];
    }
  if (stroke != nil)
    {
      [stroke set];
      [path setLineWidth: 1.0];
      [path stroke];
    }
}

/* The default button (Return). Every window's, not only the key
   window's: a panel's buttons are drawn before it becomes key and not
   again when it does, which left a dialog's default button grey. */
static BOOL
NBIsDefaultButton(NSCell *cell)
{
  if (![cell isKindOfClass: [NSButtonCell class]] || ![cell isEnabled])
    return NO;
  return [[(NSButtonCell *)cell keyEquivalent] isEqualToString: @"\r"];
}

/*
 * The default button's title is dark on the accent. NSButtonCell asks
 * itself for the colour (-textColor) and GSTheme has no say in it, so
 * while this theme is active a wrapper answers for the default button
 * and calls NSButtonCell's own method for every other one, the same way
 * the miniwindow wrapper above works.
 */
typedef NSColor *(*NBTextColorIMP)(id, SEL);
static NBTextColorIMP buttonTextColor = NULL;
static BOOL darkDefaultTitle = NO;

static NSColor *
NBButtonCellTextColor(id cell, SEL cmd)
{
  if (darkDefaultTitle && NBIsDefaultButton(cell)
      && [(NSButtonCell *)cell isBordered])
    return NBHex(NBAccentText);
  return buttonTextColor(cell, cmd);
}

static void
NBInstallDefaultButtonTitle(void)
{
  Method m;

  if (buttonTextColor != NULL)
    return;
  m = class_getInstanceMethod([NSButtonCell class], @selector(textColor));
  if (m == NULL)
    return;
  buttonTextColor = (NBTextColorIMP)
    method_setImplementation(m, (IMP)NBButtonCellTextColor);
}

/*
 * Where each window style puts the title bar's buttons, in the window
 * decoration's coordinates (bounds: the whole window). NeXT: miniaturize
 * at the left, close at the right, 16 points square. Mac: the traffic
 * lights at the left, close, minimize, zoom. Tiling: minimize, maximize
 * and close at the right, each the height of the title bar and wider, as
 * on Windows.
 */
static const CGFloat NBButtonSize = 16.0;
static const CGFloat NBTilingButtonWidth = 40.0;

static NSRect
NBButtonFrame(NSWindowButton which, NSRect b)
{
  CGFloat top = NSHeight(b) - NBButtonSize - floor((NBTitleHeight - NBButtonSize) / 2);

  if ([nbWindowStyle isEqual: @"mac"])
    {
      CGFloat slot = which == NSWindowCloseButton ? 0
                   : which == NSWindowMiniaturizeButton ? 1 : 2;
      return NSMakeRect(8 + slot * 20, top, NBButtonSize, NBButtonSize);
    }
  if ([nbWindowStyle isEqual: @"tiling"])
    {
      CGFloat slot = which == NSWindowCloseButton ? 1
                   : which == NSWindowZoomButton ? 2 : 3;
      return NSMakeRect(NSWidth(b) - 1 - slot * NBTilingButtonWidth,
                        NSHeight(b) - NBTitleHeight + 1,
                        NBTilingButtonWidth, NBTitleHeight - 2);
    }
  if (which == NSWindowCloseButton)
    return NSMakeRect(NSWidth(b) - NBButtonSize - 6, top, NBButtonSize, NBButtonSize);
  return NSMakeRect(6, top, NBButtonSize, NBButtonSize);
}

/* How far the title keeps from each side, so it stays centred clear of
   the buttons. */
static CGFloat
NBTitleInset(void)
{
  if ([nbWindowStyle isEqual: @"mac"])
    return 76;
  if ([nbWindowStyle isEqual: @"tiling"])
    return 3 * NBTilingButtonWidth + 10;
  return NBButtonSize + 10;
}

/*
 * Window buttons that colour when the pointer is over them, not only
 * while pressed: faint until then, the close button red and miniaturize
 * amber (their H images) under the pointer. GSTheme makes these buttons
 * (-standardWindowButton:forStyleMask: below); this theme makes each one
 * an NBTitleButton, NSButton with a tracking rect over itself and no
 * instance variables of its own, so the class can be swapped in place.
 */
@interface NBTitleButton : NSButton
@end

static char NBHoverKey;
static char NBTrackKey;

@implementation NBTitleButton

- (BOOL) nbHover
{
  return [objc_getAssociatedObject(self, &NBHoverKey) boolValue];
}

- (void) nbSetHover: (BOOL)hover
{
  if (hover == [self nbHover])
    return;
  objc_setAssociatedObject(self, &NBHoverKey,
    hover ? [NSNumber numberWithBool: YES] : nil, OBJC_ASSOCIATION_RETAIN);
  /* The traffic lights show their symbols together, as on a Mac. */
  {
    NSEnumerator *e = [[[self superview] subviews] objectEnumerator];
    NSView *v;
    while ((v = [e nextObject]) != nil)
      if ([v isKindOfClass: [NBTitleButton class]])
        [v setNeedsDisplay: YES];
  }
  [self setNeedsDisplay: YES];
}

/* Whether the pointer is over any of the window's buttons. */
- (BOOL) nbGroupHover
{
  NSEnumerator *e = [[[self superview] subviews] objectEnumerator];
  NSView *v;

  while ((v = [e nextObject]) != nil)
    if ([v isKindOfClass: [NBTitleButton class]] && [(NBTitleButton *)v nbHover])
      return YES;
  return NO;
}

/*
 * GNUstep's title bar has close and miniaturize buttons only; the Mac and
 * Tiling styles add zoom (maximize), a button of the same kind, placed
 * whenever the decoration places the close button (on every layout, a
 * resize and a theme change included) and removed in the NeXT style.
 * Only a resizable window gets one.
 */
- (void) nbSyncZoom
{
  NSView *bar = [self superview];
  NSWindow *w = [self target];
  NSButton *zoom = nil;
  NSEnumerator *e = [[bar subviews] objectEnumerator];
  NSView *v;

  /* Only the title bar's own buttons: -viewWithTag: would search the
     window's content too and find any control tagged 2. */
  while ((v = [e nextObject]) != nil)
    if ([v isKindOfClass: [NBTitleButton class]]
        && [(NSButton *)v tag] == NSWindowZoomButton)
      zoom = (NSButton *)v;
  BOOL want = bar != nil && ![nbWindowStyle isEqual: @"nextstep"]
    && [w isKindOfClass: [NSWindow class]]
    && ([w styleMask] & NSResizableWindowMask) != 0;

  if (!want)
    {
      [zoom removeFromSuperview];
      return;
    }
  if (zoom == nil)
    {
      zoom = AUTORELEASE([[NSButton alloc] initWithFrame: NSZeroRect]);
      object_setClass(zoom, [NBTitleButton class]);
      [zoom setTag: NSWindowZoomButton];
      [zoom setBordered: NO];
      [zoom setButtonType: NSMomentaryChangeButton];
      [zoom setImagePosition: NSImageOnly];
      [zoom setRefusesFirstResponder: YES];
      [zoom setTarget: w];
      [zoom setAction: @selector(zoom:)];
      [bar addSubview: zoom];
    }
  [zoom setFrame: NBButtonFrame(NSWindowZoomButton, [bar bounds])];
}

- (void) nbUntrack
{
  NSNumber *tag = objc_getAssociatedObject(self, &NBTrackKey);

  if (tag != nil)
    {
      [self removeTrackingRect: [tag integerValue]];
      objc_setAssociatedObject(self, &NBTrackKey, nil, OBJC_ASSOCIATION_RETAIN);
    }
}

- (void) nbTrack
{
  NSTrackingRectTag tag;

  [self nbUntrack];
  if ([self window] == nil)
    return;
  tag = [self addTrackingRect: [self bounds] owner: self userData: NULL
                 assumeInside: NO];
  objc_setAssociatedObject(self, &NBTrackKey,
    [NSNumber numberWithInteger: tag], OBJC_ASSOCIATION_RETAIN);
}

- (void) viewWillMoveToWindow: (NSWindow *)window
{
  [self nbUntrack];
  [self nbSetHover: NO];
  [super viewWillMoveToWindow: window];
}

- (void) viewDidMoveToWindow
{
  [super viewDidMoveToWindow];
  [self nbTrack];
}

- (void) setFrame: (NSRect)frame
{
  [super setFrame: frame];
  [self nbTrack];
  if ([self tag] == NSWindowCloseButton)
    [self nbSyncZoom];
}

/* Mac: a coloured circle, grey when the window isn't key or main; the
   pointer over any of them shows all three symbols. */
- (void) nbDrawMac
{
  NSWindow *w = [self window];
  BOOL active = [w isKeyWindow] || [w isMainWindow];
  NSInteger kind = [self tag];
  unsigned fill = kind == NSWindowCloseButton ? 0xff5f57
                : kind == NSWindowMiniaturizeButton ? 0xfebc2e : 0x28c840;
  unsigned ink = kind == NSWindowCloseButton ? 0x4d0000
               : kind == NSWindowMiniaturizeButton ? 0x5a3d00 : 0x0a4d10;
  NSRect r = NSMakeRect(floor(NSMidX([self bounds]) - 6),
                        floor(NSMidY([self bounds]) - 6), 12, 12);
  NSColor *c = active || [self nbGroupHover] ? NBHex(fill)
                                             : NBHex(nbLight ? 0xd1d1d6 : 0x3a3f4b);
  NSBezierPath *glyph = [NSBezierPath bezierPath];
  CGFloat cx = NSMidX(r), cy = NSMidY(r);

  if ([[self cell] isHighlighted])
    c = [c shadowWithLevel: 0.25];
  [c set];
  [[NSBezierPath bezierPathWithOvalInRect: r] fill];
  if ([self nbGroupHover])
    {
      [glyph setLineWidth: 1.2];
      [glyph setLineCapStyle: NSRoundLineCapStyle];
      if (kind == NSWindowCloseButton)
        {
          [glyph moveToPoint: NSMakePoint(cx - 2.5, cy - 2.5)];
          [glyph lineToPoint: NSMakePoint(cx + 2.5, cy + 2.5)];
          [glyph moveToPoint: NSMakePoint(cx - 2.5, cy + 2.5)];
          [glyph lineToPoint: NSMakePoint(cx + 2.5, cy - 2.5)];
        }
      else
        {
          [glyph moveToPoint: NSMakePoint(cx - 3, cy)];
          [glyph lineToPoint: NSMakePoint(cx + 3, cy)];
          if (kind == NSWindowZoomButton)
            {
              [glyph moveToPoint: NSMakePoint(cx, cy - 3)];
              [glyph lineToPoint: NSMakePoint(cx, cy + 3)];
            }
        }
      [NBHex(ink) set];
      [glyph stroke];
    }
  else if (kind == NSWindowCloseButton && [w isDocumentEdited])
    {
      [NBHex(ink) set];
      [[NSBezierPath bezierPathWithOvalInRect:
                       NSMakeRect(cx - 2, cy - 2, 4, 4)] fill];
    }
}

/* Tiling: flat buttons the height of the title bar, a thin symbol, a
   highlight under the pointer (red for close), as on Windows. */
- (void) nbDrawTiling
{
  NSWindow *w = [self window];
  BOOL active = [w isKeyWindow] || [w isMainWindow];
  NSInteger kind = [self tag];
  BOOL pressed = [[self cell] isHighlighted], hover = [self nbHover];
  NSRect b = [self bounds];
  CGFloat cx = floor(NSMidX(b)) + 0.5, cy = floor(NSMidY(b)) + 0.5;
  NSBezierPath *glyph = [NSBezierPath bezierPath];
  unsigned ink = active ? NBTitleText : NBTitleTextInactive;

  if (hover || pressed)
    {
      if (kind == NSWindowCloseButton)
        {
          [NBHex(pressed ? 0xb30f1c : 0xe81123) set];
          ink = 0xffffff;
        }
      else
        [NBHex(nbLight ? (pressed ? 0xcfd1d7 : 0xdcdee3)
                       : (pressed ? 0x343844 : 0x2b2f38)) set];
      NSRectFill(b);
    }
  [glyph setLineWidth: 1.0];
  if (kind == NSWindowCloseButton)
    {
      [glyph moveToPoint: NSMakePoint(cx - 5, cy - 5)];
      [glyph lineToPoint: NSMakePoint(cx + 5, cy + 5)];
      [glyph moveToPoint: NSMakePoint(cx - 5, cy + 5)];
      [glyph lineToPoint: NSMakePoint(cx + 5, cy - 5)];
    }
  else if (kind == NSWindowMiniaturizeButton)
    {
      [glyph moveToPoint: NSMakePoint(cx - 5, cy)];
      [glyph lineToPoint: NSMakePoint(cx + 5, cy)];
    }
  else if ([w isZoomed])
    {
      /* Restore: two overlapping windows. */
      [glyph appendBezierPathWithRect: NSMakeRect(cx - 5, cy - 5, 8, 8)];
      [glyph moveToPoint: NSMakePoint(cx - 3, cy + 3)];
      [glyph lineToPoint: NSMakePoint(cx - 3, cy + 5)];
      [glyph lineToPoint: NSMakePoint(cx + 5, cy + 5)];
      [glyph lineToPoint: NSMakePoint(cx + 5, cy - 3)];
      [glyph lineToPoint: NSMakePoint(cx + 3, cy - 3)];
    }
  else
    [glyph appendBezierPathWithRect: NSMakeRect(cx - 5, cy - 5, 10, 10)];
  [NBHex(ink) set];
  [glyph stroke];
}

- (void) mouseEntered: (NSEvent *)event
{
  [self nbSetHover: YES];
}

- (void) mouseExited: (NSEvent *)event
{
  [self nbSetHover: NO];
}

- (void) drawRect: (NSRect)rect
{
  NSImage *hover = [self alternateImage];
  NSSize size;

  if ([nbWindowStyle isEqual: @"mac"])
    {
      [self nbDrawMac];
      return;
    }
  if ([nbWindowStyle isEqual: @"tiling"])
    {
      [self nbDrawTiling];
      return;
    }
  if (![self nbHover] || ![self isEnabled] || hover == nil)
    {
      [super drawRect: rect];
      return;
    }
  size = [hover size];
  [hover drawInRect: NSMakeRect(floor(NSMidX([self bounds]) - size.width / 2),
                                floor(NSMidY([self bounds]) - size.height / 2),
                                size.width, size.height)
           fromRect: NSZeroRect
          operation: NSCompositeSourceOver
           fraction: 1.0
     respectFlipped: YES
              hints: nil];
}

@end

/*
 * The scroller style changes at once in running apps. Workspace writes
 * GNUstep's keys (NSScrollViewInterfaceStyle, GSScrollerArrowsSameEnd)
 * and posts org.nextbsd.DesktopSettingsChanged with key NBScrollerStyle;
 * every app with this theme then re-reads its defaults, which empties
 * GNUstep's interface style cache, and lays out its scroll views again.
 */
@interface NBScrollerStyleObserver : NSObject
+ (void) install;
@end

@implementation NBScrollerStyleObserver

static void
NBRetile(NSView *view)
{
  NSEnumerator *e;
  NSView *sub;

  if ([view isKindOfClass: [NSScrollView class]])
    {
      [(NSScrollView *)view tile];
      [view setNeedsDisplay: YES];
    }
  e = [[view subviews] objectEnumerator];
  while ((sub = [e nextObject]) != nil)
    NBRetile(sub);
}

+ (void) install
{
  static BOOL installed = NO;

  if (installed)
    return;
  installed = YES;
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: self
       selector: @selector(desktopSettingsChanged:)
           name: @"org.nextbsd.DesktopSettingsChanged"
         object: nil];
}

+ (void) desktopSettingsChanged: (NSNotification *)note
{
  NSEnumerator *e;
  NSWindow *w;
  id key = [[note userInfo] objectForKey: @"key"];

  /* Appearance and window style: the theme activates again with them,
     which reloads its colours and images, lays out every title bar
     again and redraws every window (GSTheme -activate). */
  if ([key isEqual: @"NBAppearance"] || [key isEqual: @"NBWindowStyle"])
    {
      [[NSUserDefaults standardUserDefaults] synchronize];
      if ([[GSTheme theme] isKindOfClass: NSClassFromString(@"NextBSD")])
        [[GSTheme theme] activate];
      return;
    }
  if (![key isEqual: @"NBScrollerStyle"])
    return;
  [[NSUserDefaults standardUserDefaults] synchronize];
  e = [[NSApp windows] objectEnumerator];
  while ((w = [e nextObject]) != nil)
    if ([w contentView] != nil)
      NBRetile([[w contentView] superview] ? [[w contentView] superview]
                                           : [w contentView]);
}

@end

@implementation NextBSD

static NSDictionary *lightInfo = nil;

/* Light: the light colour list (ThemeColorsLight.clr, Tools/make-colors). */
- (NSColorList *) colors
{
  static NSColorList *light = nil;

  if (!nbLight)
    return [super colors];
  if (light == nil)
    {
      NSString *path = [[self bundle] pathForResource: @"ThemeColorsLight"
                                               ofType: @"clr"];
      if (path != nil)
        light = [[NSColorList alloc] initWithName: @"System" fromFile: path];
    }
  return light != nil ? light : [super colors];
}

- (NSColor *) colorNamed: (NSString *)name state: (GSThemeControlState)state
{
  /* A NeXT menu's title row (GSTitleView): the title in the title colour
     on the menu's own colour, so it reads in Light too (white by default). */
  if ([name isEqual: @"GSMenuBarTitle"])
    return NBHex(NBTitleText);
  if ([name isEqual: @"GSMenuBar"])
    return NBHex(NBMenu);
  if (nbLight && [name isEqual: @"highlightedTableRowBackgroundColor"])
    return NBHex(0xb6e3f2);
  if (nbLight && [name isEqual: @"highlightedTableRowTextColor"])
    return NBHex(0x1d1f24);
  return [super colorNamed: name state: state];
}

/* Light: the images that differ, through GSThemeImages, which NSImage
   asks before the theme's own images: the empty checkbox and radio, and
   the NeXT window buttons and the menus' submenu arrows (light_*.png). */
- (NSDictionary *) infoDictionary
{
  NSDictionary *info = [super infoDictionary];
  NSMutableDictionary *images;

  if (!nbLight)
    return info;
  if (lightInfo == nil)
    {
      NSMutableDictionary *d = AUTORELEASE([info mutableCopy]);
      images = [NSMutableDictionary dictionaryWithDictionary:
                  [info objectForKey: @"GSThemeImages"]];
      NSEnumerator *e;
      NSString *n;
      e = [[NSArray arrayWithObjects: @"NSSwitch", @"common_SwitchOff",
                                      @"GSSwitch", nil] objectEnumerator];
      while ((n = [e nextObject]) != nil)
        [images setObject: @"light_SwitchOff" forKey: n];
      e = [[NSArray arrayWithObjects: @"NSRadioButton", @"common_RadioOff",
                                      @"GSRadio", nil] objectEnumerator];
      while ((n = [e nextObject]) != nil)
        [images setObject: @"light_RadioOff" forKey: n];
      [images setObject: @"light_Close" forKey: @"common_Close"];
      [images setObject: @"light_Miniaturize" forKey: @"common_Miniaturize"];
      [images setObject: @"light_CloseBroken" forKey: @"common_CloseBroken"];
      e = [[NSArray arrayWithObjects: @"NSMenuArrow", @"GSMenuArrow",
                                      @"common_3DArrowRight", nil] objectEnumerator];
      while ((n = [e nextObject]) != nil)
        [images setObject: @"light_3DArrowRight" forKey: n];
      e = [[NSArray arrayWithObjects: @"NSHighlightedMenuArrow",
                                      @"common_3DArrowRightH", nil] objectEnumerator];
      while ((n = [e nextObject]) != nil)
        [images setObject: @"light_3DArrowRightH" forKey: n];
      [d setObject: images forKey: @"GSThemeImages"];
      ASSIGN(lightInfo, d);
    }
  return lightInfo;
}

- (void) activate
{
  /* Read the appearance and window style first: GSTheme's -activate asks
     for the colours (-colors) and images (-infoDictionary) by them. */
  NBReadSettings([super infoDictionary]);
  DESTROY(lightInfo);
  [super activate];
  NBInstallMiniwindowIconFit();
  fitMiniwindowIcons = (miniWindowSetImage != NULL);
  NBInstallDefaultButtonTitle();
  darkDefaultTitle = (buttonTextColor != NULL);
  [NBScrollerStyleObserver install];
}

- (void) deactivate
{
  fitMiniwindowIcons = NO;
  darkDefaultTitle = NO;
  [super deactivate];
}

/*
 * The Mac menu bar (NBMenuStyle macmenubar). Every app draws its own bar
 * and WindowServer swaps them in place when another app becomes active,
 * with status items (NSStatusItem, the Dock's extras) beside them at the
 * right end, each a small window of its own drawn as a one-item bar. So
 * the strip reads as one surface only if they all match:
 *
 *  - the same height in every app: this theme's, whatever an app's own
 *    GSMenuBarHeight default says (libs-gui's default height);
 *  - one line along the bottom, edge to edge, and nothing else:
 *    GSTheme also draws a line down the left edge and along the top of
 *    a horizontal menu, and starts the bottom one a pixel in, which
 *    would show between status items and at the bar's left end.
 *    In-window menu bars (inwindow) are horizontal menus too, and get
 *    the same single line. A theme with GSMenuHorizontalBackground
 *    tiles draws those instead.
 *  - the bar along the top of the screen is see-through, with no line:
 *    see below.
 */
- (CGFloat) menuBarHeight
{
  return 22;
}

- (void) drawBackgroundForMenuView: (NSMenuView *)menuView
                         withFrame: (NSRect)bounds
                         dirtyRect: (NSRect)dirtyRect
                        horizontal: (BOOL)horizontal
{
  if (!horizontal && [self tilesNamed: GSMenuVerticalBackground
                                state: GSThemeNormalState] == nil)
    {
      /* NeXT menus, submenus and pop-up lists, as in the design: one
         rounded panel with a thin border, see-through outside its
         corners (the window is made non-opaque and its corners cleared,
         as for title bars), the title row and the items drawn on it. */
      NSWindow *w = [menuView window];
      NSBezierPath *panel = [NSBezierPath
        bezierPathWithRoundedRect: NSInsetRect(bounds, 0.5, 0.5)
                          xRadius: 7 yRadius: 7];

      if ([w isOpaque])
        [w setOpaque: NO];
      NSRectFillUsingOperation(NSIntersectionRect(bounds, dirtyRect),
                               NSCompositeClear);
      [NBHex(NBMenu) set];
      [panel fill];
      [NBHex(NBControlBorder) set];
      [panel setLineWidth: 1];
      [panel stroke];
      return;
    }
  if (!horizontal || [self tilesNamed: GSMenuHorizontalBackground
                                state: GSThemeNormalState] != nil)
    {
      [super drawBackgroundForMenuView: menuView
                             withFrame: bounds
                             dirtyRect: dirtyRect
                            horizontal: horizontal];
      return;
    }
  /* The Mac menu bar along the top of the screen (an app's bar, or a
     status item, in a window of its own at menu bar level or above) is
     see-through with no line along the bottom, as on macOS: the same
     alpha in every bar and status item, so the strip reads as one. A
     menu bar in a window (inwindow) stays solid, with its line. */
  if ([[menuView window] level] >= NSMainMenuWindowLevel)
    {
      [[menuView window] setOpaque: NO];
      [[[self menuBarBackgroundColor]
         colorWithAlphaComponent: NBMenuBarOpacity] set];
      NSRectFill(NSIntersectionRect(bounds, dirtyRect));
      return;
    }
  [[self menuBackgroundColor] set];
  NSRectFill(NSIntersectionRect(bounds, dirtyRect));
  [[self menuBorderColor] set];
  NSRectFill(NSMakeRect(NSMinX(bounds), NSMinY(bounds),
                        NSWidth(bounds), 1.0));
}


/*
 * Push buttons, pop-up buttons and the scroller's parts: rounded, with a
 * thin border; pressed a shade darker; the default button in the accent.
 * Bezel styles this doesn't know (circular, help, disclosure...) and any
 * element the theme has tiles for are drawn as GSTheme draws them.
 */
- (void) drawButton: (NSRect)frame
                 in: (NSCell*)cell
               view: (NSView*)view
              style: (int)style
              state: (GSThemeControlState)state
{
  NSString *name = [self nameForElement: cell];
  BOOL pressed = (state == GSThemeHighlightedState
                  || state == GSThemeHighlightedFirstResponderState);

  if ([name isEqualToString: GSScrollerVerticalKnob]
      || [name isEqualToString: GSScrollerHorizontalKnob])
    {
      /* A slim knob in the middle of the slot. */
      NSRect knob = [name isEqualToString: GSScrollerVerticalKnob]
        ? NSInsetRect(frame, floor((NSWidth(frame) - 7) / 2), 1)
        : NSInsetRect(frame, 1, floor((NSHeight(frame) - 7) / 2));
      NBRoundRect(knob, 3.5, NBHex(pressed ? NBKnobPressed : NBKnob), nil);
      return;
    }
  if ([name hasPrefix: @"GSScroller"])
    {
      /* The arrows: no button around them, only the arrow. */
      if (pressed)
        NBRoundRect(NSInsetRect(frame, 1, 1), 3, NBHex(NBControl), nil);
      return;
    }
  if ((name != nil && [self tilesNamed: name state: state] != nil))
    {
      [super drawButton: frame in: cell view: view style: style state: state];
      return;
    }
  switch (style)
    {
      /* 0 is GNUstep's default for a button made in code (no style set),
         which is most of them. */
      case 0:
      case NSNeXTBezelStyle:
      case NSPushButtonBezelStyle:
      case NSRoundRectBezelStyle:
      case NSTexturedRoundedBezelStyle:
      case NSRoundedBezelStyle:
      case NSTexturedSquareBezelStyle:
      case NSSmallSquareBezelStyle:
      case NSRegularSquareBezelStyle:
      case NSShadowlessSquareBezelStyle:
      case NSThickSquareBezelStyle:
      case NSThickerSquareBezelStyle:
        break;
      default:
        [super drawButton: frame in: cell view: view style: style state: state];
        return;
    }
  if (style == NSRoundedBezelStyle || style == 0)
    {
      /* GNUstep's rounded push buttons leave room for a NeXT bevel
         around the face; use a little of it. */
      frame = NSInsetRect(frame, 1, 2);
    }
  if (NBIsDefaultButton(cell) && [cell isKindOfClass: [NSButtonCell class]]
      && ![cell isKindOfClass: [NSPopUpButtonCell class]])
    {
      NSColor *accent = NBHex(NBAccent);
      if (pressed)
        accent = [accent shadowWithLevel: 0.15];
      NBRoundRect(frame, NBRadius, accent, accent);
      return;
    }
  if (state == GSThemeSelectedState
      || state == GSThemeSelectedFirstResponderState)
    {
      /* An on/off button that is on (a toolbar's view buttons). */
      NBRoundRect(frame, NBRadius, [NSColor selectedControlColor],
                  NBHex(NBControlBorder));
      return;
    }
  NBRoundRect(frame, NBRadius,
              NBHex(pressed ? NBControlPressed : NBControl),
              NBHex(NBControlBorder));
}

/* The default button shows by its colour, as on macOS, not by GNUstep's
   Return arrow beside its title (which also squeezed the title). A
   button given the arrow image elsewhere loses it here too. */
- (void) setKeyEquivalent: (NSString *)key
            forButtonCell: (NSButtonCell *)cell
{
  if ([cell image] == [NSImage imageNamed: @"common_ret"])
    {
      [cell setImage: nil];
      [cell setAlternateImage: nil];
    }
}

/* Scrollers: a slot the colour of the window, no dimple in the knob. */
- (NSCell*) cellForScrollerKnob: (BOOL)horizontal
{
  NSButtonCell *cell = (NSButtonCell *)[super cellForScrollerKnob: horizontal];

  [cell setImage: nil];
  return cell;
}

- (NSCell*) cellForScrollerKnobSlot: (BOOL)horizontal
{
  NSButtonCell *cell = (NSButtonCell *)[super cellForScrollerKnobSlot: horizontal];

  /* The system colour, not a fixed one: a scroller made in Dark keeps
     its slot cell, and must change with the appearance. */
  [cell setBackgroundColor: [NSColor scrollBarColor]];
  return cell;
}

- (float) defaultScrollerWidth
{
  if ([[NSUserDefaults standardUserDefaults]
        objectForKey: @"GSScrollerDefaultWidth"] != nil)
    return [super defaultScrollerWidth];
  return 14.0;
}

/*
 * Sliders, as in the design: a thin rounded track, filled with the accent
 * up to the knob (grey in a window that isn't key), and a light round
 * knob with a thin border. Circular sliders and themes with track tiles
 * are drawn as GSTheme draws them.
 */
static BOOL
NBPlainLinearSlider(NSCell *cell, GSTheme *theme, BOOL horizontal)
{
  return [(NSSliderCell *)cell sliderType] == NSLinearSlider
    && [theme tilesNamed: (horizontal ? GSSliderHorizontalTrack
                                      : GSSliderVerticalTrack)
                   state: GSThemeNormalState] == nil;
}

- (void) drawSliderBorderAndBackground: (NSBorderType)aType
                                 frame: (NSRect)cellFrame
                                inCell: (NSCell *)cell
                          isHorizontal: (BOOL)horizontal
{
  if (NBPlainLinearSlider(cell, self, horizontal))
    return;		/* the track is drawn in -drawBarInside: */
  [super drawSliderBorderAndBackground: aType frame: cellFrame inCell: cell
                          isHorizontal: horizontal];
}

- (void) drawBarInside: (NSRect)rect
                inCell: (NSCell *)cell
               flipped: (BOOL)flipped
{
  BOOL horizontal = NSWidth(rect) > NSHeight(rect);
  NSSliderCell *slider = (NSSliderCell *)cell;
  NSRect knob, track, filled;
  BOOL active;

  if (!NBPlainLinearSlider(cell, self, horizontal))
    {
      [super drawBarInside: rect inCell: cell flipped: flipped];
      return;
    }
  knob = [slider knobRectFlipped: flipped];
  active = [[[cell controlView] window] isKeyWindow] && [cell isEnabled];
  if (horizontal)
    {
      track = NSMakeRect(NSMinX(rect) + 2, floor(NSMidY(rect)) - 2,
                         NSWidth(rect) - 4, 4);
      filled = track;
      filled.size.width = MAX(0, NSMidX(knob) - NSMinX(track));
    }
  else
    {
      track = NSMakeRect(floor(NSMidX(rect)) - 2, NSMinY(rect) + 2,
                         4, NSHeight(rect) - 4);
      filled = track;
      if (flipped)
        {
          filled.origin.y = NSMidY(knob);
          filled.size.height = MAX(0, NSMaxY(track) - NSMidY(knob));
        }
      else
        filled.size.height = MAX(0, NSMidY(knob) - NSMinY(track));
    }
  [NBHex(NBFieldBorder) set];
  [[NSBezierPath bezierPathWithRoundedRect: track xRadius: 2 yRadius: 2] fill];
  [NBHex(active ? NBAccent : 0x8a8f9b) set];
  [[NSBezierPath bezierPathWithRoundedRect: filled xRadius: 2 yRadius: 2] fill];
}

- (void) drawKnobInCell: (NSCell *)cell
{
  NSView *view = [cell controlView];
  NSSliderCell *slider = (NSSliderCell *)cell;
  NSRect knob = [slider knobRectFlipped: [view isFlipped]];
  BOOL horizontal = NSWidth([view bounds]) > NSHeight([view bounds]);
  NSRect dot;

  if (!NBPlainLinearSlider(cell, self, horizontal))
    {
      [super drawKnobInCell: cell];
      return;
    }
  dot = NSMakeRect(floor(NSMidX(knob) - 7.5) + 0.5, floor(NSMidY(knob) - 7.5) + 0.5,
                   14, 14);
  [NBHex(0xf1f2f5) set];
  [[NSBezierPath bezierPathWithOvalInRect: dot] fill];
  [NBHex(0x9a9daa) set];
  [[NSBezierPath bezierPathWithOvalInRect: dot] stroke];
}

/* Text fields and other bezeled boxes: a dark well, rounded, thin border. */
- (NSRect) drawWhiteBezel: (NSRect)border withClip: (NSRect)clip
{
  NBRoundRect(border, 4, NBHex(NBField), NBHex(NBFieldBorder));
  return NSInsetRect(border, 2, 2);
}

- (NSRect) drawGrayBezel: (NSRect)border withClip: (NSRect)clip
{
  NBRoundRect(border, 4, NBHex(NBField), NBHex(NBFieldBorder));
  return NSInsetRect(border, 2, 2);
}

/*
 * The focus ring, as on macOS: text fields, lists and other views you
 * type into show it; buttons, checkboxes, pop-ups, sliders and segmented
 * controls only with full keyboard access on (AppleKeyboardUIMode 2 in
 * NSGlobalDomain). Without this a window opened with a ring around
 * whichever button got the focus first (File Viewer's Back, Preferences'
 * first checkbox).
 */
static BOOL
NBRingForControl(NSView *view)
{
  if (!([view isKindOfClass: [NSButton class]]
        || [view isKindOfClass: [NSSegmentedControl class]]
        || [view isKindOfClass: [NSSlider class]]
        || [view isKindOfClass: [NSStepper class]]
        || ([view isKindOfClass: [NSMatrix class]]
            && [[(NSMatrix *)view prototype] isKindOfClass: [NSButtonCell class]])))
    return YES;
  return ([[NSUserDefaults standardUserDefaults]
            integerForKey: @"AppleKeyboardUIMode"] & 2) != 0;
}

- (void) drawFocusFrame: (NSRect)frame view: (NSView*)view
{
  if (!NBRingForControl(view))
    return;
  NBRoundRect(NSInsetRect(frame, -1, -1), 5, nil,
              [NBHex(NBAccent) colorWithAlphaComponent: 0.9]);
}

/* Table headers: flat, on the window's colour, quiet labels, a hairline
   under them and short ones between the columns. */
- (NSColor *) tableHeaderTextColorForState: (GSThemeControlState)state
{
  return state == GSThemeHighlightedState ? NBHex(NBTitleText) : NBHex(NBHeaderText);
}

- (void) drawTableHeaderCell: (NSTableHeaderCell *)cell
                   withFrame: (NSRect)cellFrame
                      inView: (NSView *)controlView
                       state: (GSThemeControlState)state
{
  BOOL flipped = [controlView isFlipped];

  [NBHex(state == GSThemeHighlightedState ? NBHeaderPressed : NBPlane) set];
  NSRectFill(cellFrame);
  [NBHex(NBSeparator) set];
  NSRectFill(NSMakeRect(NSMinX(cellFrame),
                        flipped ? NSMaxY(cellFrame) - 1 : NSMinY(cellFrame),
                        NSWidth(cellFrame), 1));
  NSRectFill(NSMakeRect(NSMaxX(cellFrame) - 1, NSMinY(cellFrame) + 4,
                        1, NSHeight(cellFrame) - 8));
}

- (void) drawTableCornerView: (NSView*)cornerView
                    withClip: (NSRect)aRect
{
  NSRect r = [cornerView bounds];

  [NBHex(NBPlane) set];
  NSRectFill(aRect);
  [NBHex(NBSeparator) set];
  NSRectFill(NSMakeRect(NSMinX(r), [cornerView isFlipped] ? NSMaxY(r) - 1 : NSMinY(r),
                        NSWidth(r), 1));
}

/*
 * Title bars: flat, a hairline under them, the title centred between
 * the buttons; a window that isn't key goes darker with a dim title.
 * inputState is GSTheme's: 0 key, 1 neither, 2 main but not key.
 */
- (float) titlebarHeight
{
  return NBTitleHeight;
}

- (NSButton *) standardWindowButton: (NSWindowButton)button
                       forStyleMask: (NSUInteger)mask
{
  NSButton *b = [super standardWindowButton: button forStyleMask: mask];

  if ([b class] == [NSButton class])
    object_setClass(b, [NBTitleButton class]);
  [b setTag: button];
  return b;
}

- (NSRect) closeButtonFrameForBounds: (NSRect)bounds
{
  return NBButtonFrame(NSWindowCloseButton, bounds);
}

- (NSRect) miniaturizeButtonFrameForBounds: (NSRect)bounds
{
  return NBButtonFrame(NSWindowMiniaturizeButton, bounds);
}

- (float) titlebarButtonSize
{
  return 16.0;
}

- (float) titlebarPaddingTop
{
  return floor((NBTitleHeight - [self titlebarButtonSize]) / 2);
}

- (float) titlebarPaddingLeft
{
  return 6.0;
}

- (float) titlebarPaddingRight
{
  return 6.0;
}

- (void) drawTitleBarRect: (NSRect)titleBarRect
             forStyleMask: (unsigned int)styleMask
                    state: (int)inputState
                 andTitle: (NSString*)title
{
  BOOL key = (inputState == 0);
  NSRect work = titleBarRect;

  [NBHex(key ? NBTitle : NBTitleInactive) set];
  NSRectFill(titleBarRect);
  [NBHex(NBSeparator) set];
  NSRectFill(NSMakeRect(NSMinX(titleBarRect), NSMinY(titleBarRect),
                        NSWidth(titleBarRect), 1));

  if ((styleMask & NSTitledWindowMask) && [title length] > 0)
    {
      NSMutableParagraphStyle *p = AUTORELEASE([[NSParagraphStyle
        defaultParagraphStyle] mutableCopy]);
      NSFont *font = [NSFont boldSystemFontOfSize: 0];
      NSDictionary *attrs;
      NSSize size;
      CGFloat inset = NBTitleInset();

      [p setLineBreakMode: NSLineBreakByTruncatingTail];
      attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        font, NSFontAttributeName,
        NBHex(key ? NBTitleText : NBTitleTextInactive),
          NSForegroundColorAttributeName,
        p, NSParagraphStyleAttributeName, nil];
      /* The same room on both sides, so the title stays centred. */
      work = NSInsetRect(work, inset, 0);
      size = [title sizeWithAttributes: attrs];
      if (size.width < NSWidth(work))
        work.origin.x = NSMidX(work) - size.width / 2;
      work.size.width = MIN(size.width, NSWidth(work));
      work.origin.y = NSMidY(titleBarRect) - size.height / 2;
      work.size.height = size.height;
      [title drawInRect: work withAttributes: attrs];
    }
}

- (void) drawWindowBorder: (NSRect)rect
                withFrame: (NSRect)frame
             forStyleMask: (unsigned int)styleMask
                    state: (int)inputState
                 andTitle: (NSString*)title
{
  if (styleMask & (NSTitledWindowMask | NSClosableWindowMask
                   | NSMiniaturizableWindowMask))
    {
      CGFloat h = [self titlebarHeight];
      NSRect bar = NSMakeRect(0, NSHeight(frame) - h, NSWidth(frame), h);

      if (NSIntersectsRect(rect, bar))
        [self drawTitleBarRect: bar forStyleMask: styleMask
                         state: inputState andTitle: title];
    }
  if (styleMask & NSResizableWindowMask)
    {
      NSRect bar = NSMakeRect(0, 0, NSWidth(frame), [self resizebarHeight]);

      if (NSIntersectsRect(rect, bar))
        [self drawResizeBarRect: bar];
    }
  if (styleMask & (NSTitledWindowMask | NSClosableWindowMask
                   | NSMiniaturizableWindowMask | NSResizableWindowMask))
    {
      [NBHex(inputState == 0 ? NBWindowBorder : NBWindowBorderInactive) set];
      NSFrameRect(NSMakeRect(0, 0, NSWidth(frame), NSHeight(frame)));
    }
  /* Rounded top corners, as in the design (9 points): the title bar's
     corners are cleared and the window made see-through there, the way
     the Mac menu bar's alpha already reaches WindowServer. The content
     view fills the window to its bottom edge, so only the top corners
     can round from here. */
  if (styleMask & NSTitledWindowMask)
    {
      NSWindow *w = [[NSView focusView] window];
      CGFloat r = 9, W = NSWidth(frame), H = NSHeight(frame);
      NSBezierPath *edge = [NSBezierPath bezierPath];
      int row;

      if ([w isOpaque])
        [w setOpaque: NO];
      /* Clear what lies outside the curve, a row at a time. */
      for (row = 0; row < (int)r; row++)
        {
          CGFloat dy = r - row - 0.5;
          CGFloat out = r - sqrt(r * r - dy * dy);
          if (out <= 0)
            continue;
          NSRectFillUsingOperation(NSMakeRect(0, H - row - 1, ceil(out), 1),
                                   NSCompositeClear);
          NSRectFillUsingOperation(NSMakeRect(W - ceil(out), H - row - 1, ceil(out), 1),
                                   NSCompositeClear);
        }
      /* The border follows the rounded edge. */
      [edge moveToPoint: NSMakePoint(0.5, H - r)];
      [edge appendBezierPathWithArcWithCenter: NSMakePoint(r, H - r)
                                       radius: r - 0.5 startAngle: 180 endAngle: 90
                                    clockwise: YES];
      [edge moveToPoint: NSMakePoint(W - r, H - 0.5)];
      [edge appendBezierPathWithArcWithCenter: NSMakePoint(W - r, H - r)
                                       radius: r - 0.5 startAngle: 90 endAngle: 0
                                    clockwise: YES];
      [edge setLineWidth: 1];
      [NBHex(inputState == 0 ? NBWindowBorder : NBWindowBorderInactive) set];
      [edge stroke];
    }
}

/*
 * Tabs along the top: the selected tab a raised rounded control, the
 * others plain labels, over a panel with a thin rounded border. The tabs
 * keep GSTheme's positions (each label's own width plus the gaps the
 * tab images would take), so clicking works as before.
 */
- (void) drawTabViewRect: (NSRect)rect
                  inView: (NSView *)view
               withItems: (NSArray *)items
            selectedItem: (NSTabViewItem *)selected
{
  NSTabViewType type = [(NSTabView *)view tabViewType];
  NSRect bounds = [view bounds];
  NSRect panel;
  BOOL truncate;
  CGFloat tabHeight, x, y;
  NSUInteger i, n = [items count];

  if (type != NSTopTabsBezelBorder)
    {
      [super drawTabViewRect: rect inView: view withItems: items
                selectedItem: selected];
      return;
    }
  panel = [self tabViewBackgroundRectForBounds: bounds tabViewType: type];
  NBRoundRect(panel, 7, nil, NBHex(NBSeparator));
  truncate = [(NSTabView *)view allowsTruncatedLabels];
  tabHeight = [self tabHeightForType: type];
  x = NSMinX(bounds);
  y = NSMinY(bounds);
  if ([view isFlipped] == NO)
    y = NSMaxY(panel);
  for (i = 0; i < n; i++)
    {
      NSTabViewItem *item = [items objectAtIndex: i];
      NSSize s = [item sizeOfLabel: truncate];
      NSImage *gap = [self imageForTabPart: (i == 0 ? GSTabSelectedLeft
                                             : GSTabUnSelectedJunction)
                                      type: type];
      NSRect r;

      x += gap ? [gap size].width : 8;
      r = NSMakeRect(x, y, s.width, tabHeight);
      if ([item tabState] == NSSelectedTab)
        NBRoundRect(NSInsetRect(r, -8, 1), NBRadius, NBHex(NBControl),
                    NBHex(NBControlBorder));
      [item drawLabel: truncate inRect: r];
      x += s.width;
    }
}

/* Menu items: the menu's colour, no bevel between them, a rounded
   highlight inset from the panel's edge. */
- (NSColor *) menuBackgroundColor
{
  return NBHex(NBMenu);
}

- (NSColor *) menuItemBackgroundColor
{
  return NBHex(NBMenu);
}

- (NSColor *) menuBorderColor
{
  return NBHex(NBControlBorder);
}

- (BOOL) drawsBorderForMenuItemCell: (NSMenuItemCell *)cell
                              state: (GSThemeControlState)state
                       isHorizontal: (BOOL)horizontal
{
  return NO;
}

- (CGFloat) menuItemBackgroundRadius
{
  return 4.0;
}

- (NSEdgeInsets) menuItemAreaInsets
{
  return NSEdgeInsetsMake(4.0, 4.0, 4.0, 4.0);
}

/* The title row of a NeXT menu: on the panel, with a hairline under it,
   not GSTheme's black bar. GNUstep draws the title in the rect returned. */
- (NSRect) drawMenuTitleBackground: (GSTitleView *)aTitleView
                        withBounds: (NSRect)bounds
                          withClip: (NSRect)clipRect
{
  if ([self tilesNamed: GSMenuTitleBackground state: GSThemeNormalState] != nil)
    return [super drawMenuTitleBackground: aTitleView withBounds: bounds
                                 withClip: clipRect];
  [NBHex(NBSeparator) set];
  NSRectFill(NSMakeRect(NSMinX(bounds) + 6, NSMinY(bounds), NSWidth(bounds) - 12, 1));
  return NSInsetRect(bounds, 4, 0);
}

/* GNUstep hardcodes a light gray resize bar when a theme has no tiles for it. */
- (void) drawResizeBarRect: (NSRect)resizeBarRect
{
  CGFloat width = resizeBarRect.size.width;
  CGFloat height = resizeBarRect.size.height;
  CGFloat notch = [self resizebarNotchWidth];

  [[NSColor controlColor] set];
  PSrectfill(0.0, 0.0, width, height);

  PSsetlinewidth(1.0);
  [[NSColor windowFrameColor] set];
  PSmoveto(0.0, 0.5);
  PSlineto(width, 0.5);
  PSstroke();
  [[NSColor controlHighlightColor] set];
  PSmoveto(0.0, height - 0.5);
  PSlineto(width, height - 0.5);
  PSstroke();

  if (width >= notch * 2)
    {
      [[NSColor controlDarkShadowColor] set];
      PSmoveto(notch + 0.5, 1.0);
      PSlineto(notch + 0.5, height - 1.0);
      PSmoveto(width - notch - 0.5, 1.0);
      PSlineto(width - notch - 0.5, height - 1.0);
      PSstroke();
    }
}

@end

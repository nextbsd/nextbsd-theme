#import <AppKit/AppKit.h>
#import <AppKit/PSOperators.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>

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

enum {
  NBControl = 0x23262e, NBControlPressed = 0x1a1c22, NBControlBorder = 0x3a3f4b,
  NBField = 0x0b0c10, NBFieldBorder = 0x2e323c, NBAccent = 0x00d4ff,
  NBAccentText = 0x04141a, NBTitle = 0x111318, NBTitleInactive = 0x0f1013,
  NBTitleText = 0xe9eaef, NBTitleTextInactive = 0x6b6f7c, NBSeparator = 0x23262e,
  NBWindowBorder = 0x333845, NBWindowBorderInactive = 0x262a32,
  NBPlane = 0x15171c, NBKnob = 0x3a3f4b, NBKnobPressed = 0x555b68
};
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

/* The default button (Return) of the key window. */
static BOOL
NBIsDefaultButton(NSCell *cell)
{
  NSView *view;

  if (![cell isKindOfClass: [NSButtonCell class]] || ![cell isEnabled])
    return NO;
  if (![[(NSButtonCell *)cell keyEquivalent] isEqualToString: @"\r"])
    return NO;
  view = [cell controlView];
  return view == nil || [[view window] isKeyWindow];
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
  [self setNeedsDisplay: YES];
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

  if (![[[note userInfo] objectForKey: @"key"]
         isEqual: @"NBScrollerStyle"])
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

- (void) activate
{
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
  if (style == NSRoundedBezelStyle)
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

  [cell setBackgroundColor: NBHex(NBPlane)];
  return cell;
}

- (float) defaultScrollerWidth
{
  if ([[NSUserDefaults standardUserDefaults]
        objectForKey: @"GSScrollerDefaultWidth"] != nil)
    return [super defaultScrollerWidth];
  return 14.0;
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
  return state == GSThemeHighlightedState ? NBHex(NBTitleText) : NBHex(0x9a9daa);
}

- (void) drawTableHeaderCell: (NSTableHeaderCell *)cell
                   withFrame: (NSRect)cellFrame
                      inView: (NSView *)controlView
                       state: (GSThemeControlState)state
{
  BOOL flipped = [controlView isFlipped];

  [NBHex(state == GSThemeHighlightedState ? 0x1d2027 : NBPlane) set];
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
  return b;
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
      CGFloat inset = [self titlebarButtonSize] + [self titlebarPaddingLeft] + 4;

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

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

@implementation NextBSD

- (void) activate
{
  [super activate];
  NBInstallMiniwindowIconFit();
  fitMiniwindowIcons = (miniWindowSetImage != NULL);
}

- (void) deactivate
{
  fitMiniwindowIcons = NO;
  [super deactivate];
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

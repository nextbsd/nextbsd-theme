#import <AppKit/AppKit.h>
#import <AppKit/PSOperators.h>
#import <GNUstepGUI/GSTheme.h>

@interface NextBSD : GSTheme
@end

@implementation NextBSD

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

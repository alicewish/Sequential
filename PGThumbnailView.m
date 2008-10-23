/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGThumbnailView.h"

// Views
#import "PGClipView.h"

// Other
#import "PGGeometry.h"

// Categories
#import "NSBezierPathAdditions.h"

#define PGThumbnailSize         128.0f
#define PGThumbnailMarginWidth  12.0
#define PGThumbnailMarginHeight 2.0f
#define PGThumbnailTotalWidth   (PGThumbnailSize + PGThumbnailMarginWidth * 2)
#define PGThumbnailTotalHeight  (PGThumbnailSize + PGThumbnailMarginHeight * 2)

@implementation PGThumbnailView

#pragma mark Instance Methods

- (id)dataSource
{
	return dataSource;
}
- (void)setDataSource:(id)obj
{
	dataSource = obj;
}
- (id)delegate
{
	return delegate;
}
- (void)setDelegate:(id)obj
{
	delegate = obj;
}
- (id)representedObject
{
	return [[_representedObject retain] autorelease];
}
- (void)setRepresentedObject:(id)obj
{
	if(obj == _representedObject) return;
	[_representedObject release];
	_representedObject = [obj retain];
}

#pragma mark -

- (NSArray *)items
{
	return [[_items retain] autorelease];
}
- (NSSet *)selection
{
	return [[_selection copy] autorelease];
}
- (void)setSelection:(NSSet *)items
{
	if(items == _selection) return;
	NSMutableSet *const removedItems = [[_selection mutableCopy] autorelease];
	[removedItems minusSet:items];
	id removedItem;
	NSEnumerator *const removedItemEnum = [removedItems objectEnumerator];
	while((removedItem = [removedItemEnum nextObject])) [self setNeedsDisplayInRect:[self frameOfItemAtIndex:[_items indexOfObjectIdenticalTo:removedItem] withMargin:YES]];
	[_selection setSet:items];
	[self scrollToFirstSelectedItem];
	[[self delegate] thumbnailViewSelectionDidChange:self];
}
- (void)scrollToFirstSelectedItem
{
	unsigned const selCount = [_selection count];
	if(1 == selCount) return [self PG_scrollRectToVisible:[self frameOfItemAtIndex:[_items indexOfObjectIdenticalTo:[_selection anyObject]] withMargin:YES]];
	else if(selCount) {
		unsigned i = 0;
		for(; i < [_items count]; i++) {
			if(![_selection containsObject:[_items objectAtIndex:i]]) continue;
			[self PG_scrollRectToVisible:[self frameOfItemAtIndex:i withMargin:YES]];
			return;
		}
	}
	[[self PG_enclosingClipView] scrollToEdge:PGMaxYEdgeMask animation:PGAllowAnimation];
}

#pragma mark -

- (unsigned)indexOfItemAtPoint:(NSPoint)p
{
	return floorf(p.y / PGThumbnailTotalHeight);
}
- (NSRect)frameOfItemAtIndex:(unsigned)index
          withMargin:(BOOL)flag
{
	NSRect frame = NSMakeRect(PGThumbnailMarginWidth, index * PGThumbnailTotalHeight + PGThumbnailMarginHeight, PGThumbnailSize, PGThumbnailSize);
	return flag ? NSInsetRect(frame, -PGThumbnailMarginWidth, -PGThumbnailMarginHeight) : frame;
}

#pragma mark -

- (void)reloadData
{
	BOOL const hadSelection = !![_selection count];
	[_items release];
	_items = [[[self dataSource] itemsForThumbnailView:self] copy];
	[self setFrameSize:NSZeroSize];
	[self scrollToFirstSelectedItem];
	[self setNeedsDisplay:YES];
	if(hadSelection) [[self delegate] thumbnailViewSelectionDidChange:self];
}

#pragma mark PGClipViewDocumentView Protocol

- (BOOL)acceptsClicksInClipView:(PGClipView *)sender
{
	return NO;
}

#pragma mark NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		_selection = (NSMutableSet *)CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
	}
	return self;
}

#pragma mark -

- (BOOL)isFlipped
{
	return YES;
}
- (void)setUpGState
{
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
}


static void PGGradientCallback(void *info, float const *inData, float *outData)
{
	outData[0] = (0.25f - powf(inData[0] - 0.5f, 2.0f)) / 2.0f + 0.1f;
	outData[1] = 0.95f;
}


- (void)drawRect:(NSRect)aRect
{
	NSRect const b = [self bounds];
	NSShadow *const nilShadow = [[[NSShadow alloc] init] autorelease];
	[nilShadow setShadowColor:nil];
	NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowOffset:NSMakeSize(0, -2)];
	[shadow setShadowBlurRadius:4.0f];
	[shadow set];

	CGContextBeginTransparencyLayer([[NSGraphicsContext currentContext] graphicsPort], NULL);

	static CGShadingRef shade = NULL;
	if(!shade) {
		CGColorSpaceRef const colorSpace = CGColorSpaceCreateDeviceGray();
		float const domain[] = {0, 1};
		float const range[] = {0, 1, 0, 1};
		CGFunctionCallbacks const callbacks = {0, PGGradientCallback, NULL};
		CGFunctionRef const function = CGFunctionCreate(NULL, 1, domain, 2, range, &callbacks);
		shade = CGShadingCreateAxial(colorSpace, CGPointMake(NSMinX(b), 0), CGPointMake(NSMinX(b) + PGThumbnailTotalWidth, 0), function, NO, NO);
		CFRelease(function);
		CFRelease(colorSpace);
	}
	CGContextDrawShading([[NSGraphicsContext currentContext] graphicsPort], shade);

	int count = 0;
	NSRect const *rects = NULL;
	[self getRectsBeingDrawn:&rects count:&count];
	unsigned i = 0;
	for(; i < [_items count]; i++) {
		NSRect const frameWithMargin = [self frameOfItemAtIndex:i withMargin:YES];
		if(!PGIntersectsRectList(frameWithMargin, rects, count)) continue;
		id const item = [_items objectAtIndex:i];
		if([_selection containsObject:item]) {
			[[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.33f] set];
			NSRectFillUsingOperation(frameWithMargin, NSCompositeSourceOver);
		}
		NSImage *const thumb = [[self dataSource] thumbnailView:self thumbnailForItem:item];
		[thumb setFlipped:[self isFlipped]];
		NSSize const originalSize = [thumb size];
		NSRect const frame = [self frameOfItemAtIndex:i withMargin:NO];
		[shadow set];
		[thumb drawInRect:PGCenteredSizeInRect(PGScaleSizeByFloat(originalSize, MIN(NSWidth(frame) / originalSize.width, NSHeight(frame) / originalSize.height)), frame) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:([[self dataSource] thumbnailView:self canSelectItem:item] ? 1.0f : 0.5f)];
		[nilShadow set];
	}

	float top = floorf(NSMinY(aRect) / 9) * 9 - 3.0f;
	for(; top < NSMaxY(aRect); top += 9) {
		[[NSColor colorWithDeviceWhite:1 alpha:0.1f] set];
		[[NSBezierPath AE_bezierPathWithRoundRect:NSMakeRect(3, top + 1, 6, 6) cornerRadius:1] fill];
		[[NSBezierPath AE_bezierPathWithRoundRect: NSMakeRect(PGThumbnailSize + PGThumbnailMarginWidth + 3, top + 1, 6, 6)cornerRadius:1] fill];

		[[NSColor clearColor] set];
		[[NSBezierPath AE_bezierPathWithRoundRect:NSMakeRect(3, top, 6, 6) cornerRadius:1] AE_fillUsingOperation:NSCompositeCopy];
		[[NSBezierPath AE_bezierPathWithRoundRect: NSMakeRect(PGThumbnailSize + PGThumbnailMarginWidth + 3, top, 6, 6)cornerRadius:1] AE_fillUsingOperation:NSCompositeCopy];
	}

	CGContextEndTransparencyLayer([[NSGraphicsContext currentContext] graphicsPort]);
	[nilShadow set];
}

#pragma mark -

- (void)setFrameSize:(NSSize)oldSize
{
	float const height = [self superview] ? NSHeight([[self superview] bounds]) : 0;
	[super setFrameSize:NSMakeSize(PGThumbnailTotalWidth + 2, MAX(height, [_items count] * PGThumbnailTotalHeight))];
}

#pragma mark NSResponder

- (void)mouseDown:(NSEvent *)anEvent
{
	NSPoint const p = [self convertPoint:[anEvent locationInWindow] fromView:nil];
	unsigned const i = [self indexOfItemAtPoint:p];
	id const item = [self mouse:p inRect:[self bounds]] && i < [_items count] ? [_items objectAtIndex:i] : nil;
	BOOL const canSelect = !dataSource || [dataSource thumbnailView:self canSelectItem:item];
	BOOL const modifyExistingSelection = !!([anEvent modifierFlags] & (NSShiftKeyMask | NSCommandKeyMask));
	if([_selection containsObject:item]) {
		if(!modifyExistingSelection) {
			[_selection removeAllObjects];
			[self setNeedsDisplay:YES];
			if(canSelect && item) [_selection addObject:item];
		} else if(item) [_selection removeObject:item];
	} else {
		if(!modifyExistingSelection) {
			[_selection removeAllObjects];
			[self setNeedsDisplay:YES];
		}
		if(canSelect && item) [_selection addObject:item];
	}
	[self setNeedsDisplayInRect:[self frameOfItemAtIndex:i withMargin:YES]];
	[[self delegate] thumbnailViewSelectionDidChange:self];
}

#pragma mark NSObject

- (void)dealloc
{
	[_representedObject release];
	[_selection release];
	[super dealloc];
}

@end

@implementation NSObject (PGThumbnailViewDataSource)

- (NSArray *)itemsForThumbnailView:(PGThumbnailView *)sender
{
	return nil;
}
- (NSImage *)thumbnailView:(PGThumbnailView *)sender
             thumbnailForItem:(id)item
{
	return nil;
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender
        canSelectItem:(id)item;
{
	return YES;
}

@end

@implementation NSObject (PGThumbnailViewDelegate)

- (void)thumbnailViewSelectionDidChange:(PGThumbnailView *)sender {}

@end
/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGWebKitAdditions.h"

// Models
#import "PGResourceIdentifier.h"

@implementation DOMHTMLDocument(PGWebKitAdditions)

- (NSArray *)PG_linkHrefIdentifiersWithSchemes:(NSArray *)schemes extensions:(NSArray *)exts
{
	NSMutableArray *const results = [NSMutableArray array];
	DOMHTMLCollection *const links = [self links];
	NSUInteger i = 0;
	NSUInteger const count = [links length];
	for(; i < count; i++) {
		NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
		do {
			DOMHTMLAnchorElement *const a = (DOMHTMLAnchorElement *)[links item:i];
			NSString *href = [a href];
			NSUInteger anchorStart = [href rangeOfString:@"#" options:NSBackwardsSearch].location;
			if(NSNotFound != anchorStart) href = [href substringToIndex:anchorStart];
			if(!href || [@"" isEqualToString:href]) continue;
			NSURL *const URL = [NSURL URLWithString:href];
			if((schemes && ![schemes containsObject:[[URL scheme] lowercaseString]]) || (exts && ![exts containsObject:[[[URL path] pathExtension] lowercaseString]])) continue;
			PGDisplayableIdentifier *const ident = [URL PG_displayableIdentifier];
			if([results containsObject:ident]) continue;
			[ident setCustomDisplayName:[[a innerText] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
			[results addObject:ident];
		} while(NO);
		[pool release];
	}
	return results;
}
- (NSArray *)PG_imageSrcIdentifiers
{
	NSMutableArray *const results = [NSMutableArray array];
	DOMHTMLCollection *const images = [self images];
	NSUInteger i = 0;
	NSUInteger const count = [images length];
	for(; i < count; i++) {
		NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
		do {
			DOMHTMLImageElement *const img = (DOMHTMLImageElement *)[images item:i];
			if([img PG_hasAncestorWithNodeName:@"A"]) continue; // I have a hypothesis that images within links are rarely interesting in and of themselves, so don't load them.
			PGDisplayableIdentifier *const ident = [[NSURL URLWithString:[img src]] PG_displayableIdentifier];
			if([results containsObject:ident]) continue;
			NSString *const title = [img title]; // Prefer the title to the alt attribute.
			[ident setCustomDisplayName:title && ![@"" isEqualToString:title] ? title : [img alt]];
			[results addObject:ident];
		} while(NO);
		[pool release];
	}
	return results;
}

@end

@implementation DOMNode(PGWebKitAdditions)

- (BOOL)PG_hasAncestorWithNodeName:(NSString *)string
{
	return [[self nodeName] isEqualToString:string] ? YES : [[self parentNode] PG_hasAncestorWithNodeName:string];
}

@end
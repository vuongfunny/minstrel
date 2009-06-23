//
//  CueSheet.m
//  CueSheet
//
//  Created by Zaphod Beeblebrox on 10/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CueSheet.h"
#import "CueSheetTrack.h"

#import "Plugin.h"

@implementation CueSheet

+ (id)cueSheetWithFile:(NSString *)filename
{
	return [[[CueSheet alloc] initWithFile:filename] autorelease];
}

- (NSURL *)urlForPath:(NSString *)path relativeTo:(NSString *)baseFilename
{
	NSRange protocolRange = [path rangeOfString:@"://"];
	if (protocolRange.location != NSNotFound) 
	{
		return [NSURL URLWithString:path];
	}

	NSMutableString *unixPath = [path mutableCopy];

	//Get the fragment
	NSString *fragment = @"";
	NSScanner *scanner = [NSScanner scannerWithString:unixPath];
	NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"#1234567890"];
	while (![scanner isAtEnd]) {
		NSString *possibleFragment;
		[scanner scanUpToString:@"#" intoString:nil];

		if ([scanner scanCharactersFromSet:characterSet intoString:&possibleFragment] && [scanner isAtEnd]) 
		{
			fragment = possibleFragment;
			[unixPath deleteCharactersInRange:NSMakeRange([scanner scanLocation] - [possibleFragment length], [possibleFragment length])];
			break;
		}
	}

	if (![unixPath hasPrefix:@"/"]) {
		//Only relative paths would have windows backslashes.
		[unixPath replaceOccurrencesOfString:@"\\" withString:@"/" options:0 range:NSMakeRange(0, [unixPath length])];
		
		NSString *basePath = [[[baseFilename stringByStandardizingPath] stringByDeletingLastPathComponent] stringByAppendingString:@"/"];

		[unixPath insertString:basePath atIndex:0];
	}
	
	//Append the fragment
	NSURL *url = [NSURL URLWithString:[[[NSURL fileURLWithPath:unixPath] absoluteString] stringByAppendingString: fragment]];
	[unixPath release];
	return url;
}



//-----------Added by K.O.ed 2009.06.23-------------
// Enabling encoding detection, codes come from XLD by tmkk
char *fgets_private(char *buf, int size, FILE *fp)
{
	int i;
	char c;
	
	for(i=0;i<size-1;) {
		if(fread(&c,1,1,fp) != 1) break;
		buf[i++] = c;
		if(c == '\n' || c == '\r') {
			break;
		}
	}
	if(i==0) return NULL;
	buf[i] = 0;
	return buf;
}

NSStringEncoding detectEncoding(FILE *fp)
{
	char buf[2048];
	char tmp[2048];
	char *ptr = buf;
	int len = 0;
	int minLength = INT_MAX;
	off_t pos = ftello(fp);
	CFStringRef asciiStr;
	CFStringRef sjisStr;
	CFStringRef cp932Str;
	CFStringRef jisStr;
	CFStringRef eucStr;
	CFStringRef utf8Str;
	int asciiLength;
	int sjisLength;
	int cp932Length;
	int jisLength;
	int eucLength;
	int utf8Length;
	
	
	while(fgets_private(tmp,2048,fp) != NULL) {
		int ret = strlen(tmp);
		len += ret;
		if(len > 2048) {
			len -= ret;
			break;
		}
		memcpy(ptr,tmp,ret);
		ptr += ret;
	}
	
	asciiStr = CFStringCreateWithBytes(NULL, (const UInt8 *)buf, len,  kCFStringEncodingASCII,false);
	sjisStr = CFStringCreateWithBytes(NULL, (const UInt8 *)buf, len, kCFStringEncodingShiftJIS,false);
	cp932Str = CFStringCreateWithBytes(NULL, (const UInt8 *)buf, len, kCFStringEncodingDOSJapanese,false);
	jisStr = CFStringCreateWithBytes(NULL, (const UInt8 *)buf, len, kCFStringEncodingISO_2022_JP,false);
	eucStr = CFStringCreateWithBytes(NULL, (const UInt8 *)buf, len, kCFStringEncodingEUC_JP,false);
	utf8Str = CFStringCreateWithBytes(NULL, (const UInt8 *)buf, len, kCFStringEncodingUTF8,false);
	
	asciiLength = (asciiStr) ? CFStringGetLength(asciiStr) : INT_MAX;
	sjisLength = (sjisStr) ? CFStringGetLength(sjisStr) : INT_MAX;
	cp932Length = (cp932Str) ? CFStringGetLength(cp932Str) : INT_MAX;
	jisLength = (jisStr) ? CFStringGetLength(jisStr) : INT_MAX;
	eucLength = (eucStr) ? CFStringGetLength(eucStr) : INT_MAX;
	utf8Length = (utf8Str) ? CFStringGetLength(utf8Str) : INT_MAX;
	
	if(asciiLength < minLength) minLength = asciiLength;
	if(sjisLength < minLength) minLength = sjisLength;
	if(cp932Length < minLength) minLength = cp932Length;
	if(jisLength < minLength) minLength = jisLength;
	if(eucLength < minLength) minLength = eucLength;
	if(utf8Length < minLength) minLength = utf8Length;
	
	//NSLog(@"%d,%d,%d,%d,%d,%d\n",asciiLength,sjisLength,cp932Length,jisLength,eucLength,utf8Length);
	
	if(asciiStr) CFRelease(asciiStr);
	if(sjisStr) CFRelease(sjisStr);
	if(cp932Str) CFRelease(cp932Str);
	if(jisStr) CFRelease(jisStr);
	if(eucStr) CFRelease(eucStr);
	if(utf8Str) CFRelease(utf8Str);
	fseeko(fp,pos,SEEK_SET);
	
	if(minLength == INT_MAX) return [NSString defaultCStringEncoding];
	if(minLength == asciiLength) return [NSString defaultCStringEncoding];
	if(minLength == sjisLength) return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingShiftJIS);
	if(minLength == cp932Length) return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese);
	if(minLength == utf8Length) return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF8);
	if(minLength == eucLength) return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP);
	if(minLength == jisLength) return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP);
	
	return [NSString defaultCStringEncoding];
}
//-----------Added END-------------

- (void)parseFile:(NSString *)filename
{
	//-------Modified by K.O.ed @ 2009.06.23---------
	/* Original:
	NSStringEncoding encoding;
	 */
	FILE *fp = fopen([filename UTF8String],"rb");
	NSStringEncoding encoding = detectEncoding(fp);
	//-------Modified END----------------
	NSError *error = nil;
	NSString *contents = [NSString stringWithContentsOfFile:filename usedEncoding:&encoding error:&error];
    if (error) {
        error = nil;
        contents = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:&error];
    }
    if (error) {
        error = nil;
        contents = [NSString stringWithContentsOfFile:filename encoding:NSWindowsCP1251StringEncoding error:&error];
	}
    if (error) {
        error = nil;
        contents = [NSString stringWithContentsOfFile:filename encoding:NSISOLatin1StringEncoding error:&error];
	}
	if (error || !contents) {
		NSLog(@"Could not open file...%@ %@ %@", filename, contents, error);
		return;
	}
	
	NSMutableArray *entries = [[NSMutableArray alloc] init];

	NSString *track = nil;
	NSString *path = nil;
	NSString *artist = nil;
	NSString *album = nil;
	NSString *title = nil;
	NSString *genre = nil;
	NSString *year = nil;
	
	BOOL trackAdded = NO;

	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	NSString *line;
	NSScanner *scanner = nil;
	NSEnumerator *e = [[contents componentsSeparatedByString:@"\n"] objectEnumerator];
	while (line = [e nextObject])
	{
		[scanner release];
		scanner = [[NSScanner alloc] initWithString:line];

		NSString *command;
		if (![scanner scanUpToCharactersFromSet:whitespace intoString:&command]) {
			continue;
		}
		
		//FILE "filename.shn" WAVE
		if ([command isEqualToString:@"FILE"]) {
			trackAdded = NO;

			if (![scanner scanString:@"\"" intoString:nil]) {
				continue;
			}

			//Read in the path
			if (![scanner scanUpToString:@"\"" intoString:&path]) {
				continue;
			}
		}
		//TRACK 01 AUDIO
		else if ([command isEqualToString:@"TRACK"]) {
			trackAdded = NO;

			if (![scanner scanUpToCharactersFromSet:whitespace intoString:&track]) {
				continue;
			}
			
			NSString *type = nil;
			if (![scanner scanUpToCharactersFromSet:whitespace intoString:&type]
					|| ![type isEqualToString:@"AUDIO"]) {
				continue;
			}
		}
		//INDEX 01 00:00:10
		//Note that time is written in Minutes:Seconds:Frames, where frames are 1/75 of a second
		else if ([command isEqualToString:@"INDEX"]) {
			if (trackAdded) {
				continue;
			}
			
			if (!path) {
				continue;
			}

			NSString *index = nil;
			if (![scanner scanUpToCharactersFromSet:whitespace intoString:&index] || [index intValue] != 1) {
				continue;
			}
			
			[scanner scanCharactersFromSet:whitespace intoString:nil];

			NSString *time = nil;
			if (![scanner scanUpToCharactersFromSet:whitespace intoString:&time]) {
				continue;
			}
			
			NSArray *msf = [time componentsSeparatedByString:@":"];
			if ([msf count] != 3) {
				continue;
			}

			double seconds = (60*[[msf objectAtIndex:0] intValue]) + [[msf objectAtIndex:1] intValue] + ([[msf objectAtIndex:2] floatValue]/75);

			if (track == nil) {
				track = @"01";
			}

			//Need to add basePath, and convert to URL
			[entries addObject:
								[CueSheetTrack trackWithURL:[self urlForPath:path relativeTo:filename]
															track: track
															time: seconds 
															artist:artist 
															album:album 
															title:title
															genre:genre
															year:year]];
			trackAdded = YES;
		}
		else if ([command isEqualToString:@"PERFORMER"])
		{
			if (![scanner scanString:@"\"" intoString:nil]) {
				continue;
			}

			//Read in the path
			if (![scanner scanUpToString:@"\"" intoString:&artist]) {
				continue;
			}
		}
		else if ([command isEqualToString:@"TITLE"])
		{
			NSString **titleDest;
			if (!path) //Have not come across a file yet.
				titleDest = &album;
			else
				titleDest = &title;
			
			if (![scanner scanString:@"\"" intoString:nil]) {
				continue;
			}

			//Read in the path
			if (![scanner scanUpToString:@"\"" intoString:titleDest]) {
				continue;
			}
		}
		else if ([command isEqualToString:@"REM"]) //Additional metadata sometimes stored in comments
		{
			NSString *type;
			if ( ![scanner scanUpToCharactersFromSet:whitespace intoString:&type]) {
				continue;
			}
			
			if ([type isEqualToString:@"GENRE"])
			{
				//NSLog(@"GENRE!");
				if ([scanner scanString:@"\"" intoString:nil]) {
					//NSLog(@"QUOTED");
					if (![scanner scanUpToString:@"\"" intoString:&genre]) {
						NSLog(@"FAILED TO SCAN");
						continue;
					}
				}
				else {
					//NSLog(@"UNQUOTED");
					if ( ![scanner scanUpToCharactersFromSet:whitespace intoString:&genre]) {
						continue;
					}
				}
			}
			else if ([type isEqualToString:@"DATE"])
			{
				//NSLog(@"DATE!");
				if ( ![scanner scanUpToCharactersFromSet:whitespace intoString:&year]) {
					continue;
				}
			}
		}
	}

	[scanner release];
	
	tracks = [entries copy];

	[entries release];
}

- (id)initWithFile:(NSString *)filename
{
	self = [super init];
	if (self) {
		[self parseFile:filename];
	}
	
	return self;
}

- (void)dealloc
{
	[tracks release];
	
	[super dealloc];
}

- (NSArray *)tracks
{
	return tracks;
}

- (CueSheetTrack *)track:(NSString *)fragment
{
	CueSheetTrack *t;
	NSEnumerator *e = [tracks objectEnumerator];
	while (t = [e nextObject]) {
		if ([[t track] isEqualToString:fragment]) {
			return t;
		}
	}
	
	return nil;
}

@end

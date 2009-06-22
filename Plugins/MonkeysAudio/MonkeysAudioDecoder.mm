//
//  MonkeysFile.m
//  zyVorbis
//
//  Created by Vincent Spader on 1/30/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import "MonkeysAudioDecoder.h"
#import "MAC/APEInfo.h"
#import "MAC/CharacterHelper.h"

@implementation MonkeysAudioDecoder

- (BOOL)open:(id<CogSource>)s
{
	int n;
	sourceIO = new SourceIO(s);

	[self setSource:s];

	decompress = CreateIAPEDecompressEx(sourceIO, &n);

	if (decompress == NULL)
	{
		NSLog(@"ERROR OPENING FILE");
		return NO;
	}
	
	frequency = decompress->GetInfo(APE_INFO_SAMPLE_RATE);
	bitsPerSample = decompress->GetInfo(APE_INFO_BITS_PER_SAMPLE);
	channels = decompress->GetInfo(APE_INFO_CHANNELS);

	totalFrames = decompress->GetInfo(APE_INFO_TOTAL_BLOCKS);

	[self willChangeValueForKey:@"properties"];
	[self didChangeValueForKey:@"properties"];
	
	return YES;
}

- (int)readAudio:(void *)buf frames:(UInt32)frames
{
	int n;
	int numread;

	n = decompress->GetData((char *)buf, frames, &numread);
	if (n != ERROR_SUCCESS)
	{
		NSLog(@"ERROR: %i", n);
		return 0;
	}

	return numread;
}

- (void)close
{
//	DBLog(@"CLOSE");
	if (decompress)
		delete decompress;
	if (sourceIO)
		delete sourceIO;
	
	[source release];
	
	decompress = NULL;
	sourceIO = NULL;
}

- (long)seek:(long)frame
{
	int r;
//	DBLog(@"HELLO: %i", int(frequency*((double)milliseconds/1000.0)));
	r = decompress->Seek(frame);
	
	return frame;
}

- (void)setSource:(id<CogSource>)s
{
	[s retain];
	[source release];
	source = s;
}

- (id<CogSource>)source
{
	return source;
}

- (NSDictionary *)properties
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:channels],@"channels",
		[NSNumber numberWithInt:bitsPerSample],@"bitsPerSample",
		[NSNumber numberWithFloat:frequency],@"sampleRate",
		[NSNumber numberWithDouble:totalFrames],@"totalFrames",
		[NSNumber numberWithBool:[source seekable]], @"seekable",
		@"host",@"endian",
		nil];
}


+ (NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"ape"];
}

+ (NSArray *)mimeTypes
{
	return [NSArray arrayWithObjects:@"audio/x-ape", nil];
}

@end

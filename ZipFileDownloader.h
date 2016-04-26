//
//  ZipFileDownloader.h
//  CoughDrop
//
//  Created by Joshua Dutton on 2/4/16.
//
//

#import <Foundation/Foundation.h>

@interface ZipFileDownloader : NSObject
@property BOOL isDownloading;

- (void)downloadfileAtURL:(NSURL *)voiceURL
            andUnZipToURL:(NSURL *)unZipURL
            progressBlock:(void (^)(double progress, BOOL isCompleted))progressBlock
               errorBlock:(void (^)(NSString *errorMessage))errorBlock;
@end

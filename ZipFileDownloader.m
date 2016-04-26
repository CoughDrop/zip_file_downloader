//
//  ZipFileDownloader.m
//  CoughDrop
//
//  Created by Joshua Dutton on 2/4/16.
//
//

#import "ZipFileDownloader.h"
#import "SSZipArchive.h"

@interface ZipFileDownloader() <NSURLSessionDelegate, NSURLSessionDataDelegate>
@property NSURLSession *session;
@property NSURLSessionDownloadTask *downloadTask;
@property NSURL *unZipURL;

@property (nonatomic, copy) void (^progressBlock)(double progress, BOOL isCompleted);
@property (nonatomic, copy) void (^errorBlock)(NSString *errorMessage);
@end

const double DownloadPercentageWeight = 0.75;

@implementation ZipFileDownloader

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)downloadfileAtURL:(NSURL *)voiceURL
            andUnZipToURL:(NSURL *)unZipURL
            progressBlock:(void (^)(double, BOOL))progressBlock
               errorBlock:(void (^)(NSString *))errorBlock
{
    self.unZipURL = unZipURL;
    self.progressBlock = progressBlock;
    self.errorBlock = errorBlock;
    
    self.isDownloading = true;
    // Download progress is updated in the NSURLSessionDataDelegate methods
    self.downloadTask = [self.session downloadTaskWithURL:voiceURL];
    [self.downloadTask resume];
}

#pragma mark - NSURLSessionDelegate and NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    if (self.errorBlock) {
        self.errorBlock(@"unable to download file");
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    if (downloadTask == self.downloadTask) {
        [self updateProgressForDownloadWithAmountWritten:fileOffset total:expectedTotalBytes];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (downloadTask == self.downloadTask) {
        [self updateProgressForDownloadWithAmountWritten:totalBytesWritten total:totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    if (downloadTask == self.downloadTask) {
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSURL *zipFileURL = [self.unZipURL URLByAppendingPathComponent:@"toUnzip.zip"];
        NSError *error;
        [fileManager removeItemAtURL:zipFileURL error:&error];
        BOOL success = [fileManager moveItemAtURL:location toURL:zipFileURL error:&error];
        if (success) {
            [self unZipFileAtURL:zipFileURL];
        } else if (self.errorBlock) {
            self.errorBlock(@"unable to unzip file");
        }
    }
}

#pragma mark - Download and UnZip helpers

- (void)unZipFileAtURL:(NSURL *)tempFileURL
{
    [SSZipArchive unzipFileAtPath:tempFileURL.path
                    toDestination:self.unZipURL.path
                  progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total) {
                      [self updateProgressForUnZipWithAmountWritten:entryNumber total:total];
                  }
                completionHandler:^(NSString *path, BOOL succeeded, NSError *error) {
                    
                    if (succeeded && self.progressBlock) {
                        self.progressBlock(1.0, YES);
                    } else if (self.errorBlock){
                        self.errorBlock(@"unable to unzip file");
                    }
                    
                    // cleanup
                    [[NSFileManager defaultManager] removeItemAtURL:tempFileURL error:nil];
                    self.isDownloading = NO;
                    self.downloadTask = nil;
                    self.progressBlock = nil;
                    self.errorBlock = nil;
                }];
}

- (void)updateProgressForDownloadWithAmountWritten:(double)written total:(double)total
{
    double percent = written/total * DownloadPercentageWeight;
    [self updateProgressWithPercent:percent];
}

- (void)updateProgressForUnZipWithAmountWritten:(double)written total:(double)total
{
    const double unZipPercentageWeight = 1.0 - DownloadPercentageWeight;
    double percent = DownloadPercentageWeight + (written/total * unZipPercentageWeight);
    [self updateProgressWithPercent:percent];
}

- (void)updateProgressWithPercent:(double)percent
{
    double trimmedPercent = round(percent * 100.0) / 100.0;
    if (trimmedPercent >= 1.0) {
        return;
    }
    if (self.progressBlock) {
        self.progressBlock(trimmedPercent, NO);
    }
}

@end

//
//  DataWriter.m
//  media
//
//  Created by apple on 2019/8/24.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "DataWriter.h"

@implementation DataWriter

- (id)initWithPath:(NSString*)path
{
    if (self = [super init]) {
        self.savePath = path;
    }
    
    return self;
}
- (void)deletePath
{
    if (self.savePath.length == 0) {
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.savePath]){
        [[NSFileManager defaultManager] removeItemAtPath:self.savePath error:nil];
    }
}
- (void)writeDataBytes:(Byte*)dBytes len:(NSInteger)len
{
    NSData *data = [NSData dataWithBytes:dBytes length:len];
    [self writeData:data];
}
- (void)writeData:(NSData*)data
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.savePath]){
        [[NSFileManager defaultManager] createFileAtPath:self.savePath contents:nil attributes:nil];
    }
    NSFileHandle * handle = [NSFileHandle fileHandleForWritingAtPath:self.savePath];
    [handle seekToEndOfFile];
    [handle writeData:data];
}

- (BOOL)fileIsExsits
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.savePath];
}

- (void)deletePath:(NSString*)path
{
    if (path.length == 0) {
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]){
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

- (void)writeDataBytes:(Byte*)dBytes len:(NSInteger)len toPath:(NSString *)savePath
{
    NSData *data = [NSData dataWithBytes:dBytes length:len];
    [self writeData:data toPath:savePath];
}
- (void)writeData:(NSData*)data toPath:(NSString *)savePath
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:savePath]){
        [[NSFileManager defaultManager] createFileAtPath:savePath contents:nil attributes:nil];
    }
    
    NSFileHandle * handle = [NSFileHandle fileHandleForWritingAtPath:savePath];
    [handle seekToEndOfFile];
    [handle writeData:data];
}

@end

//
//  AudioDataWriter.h
//  media
//
//  Created by 飞拍科技 on 2019/6/26.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioDataWriter : NSObject
@property (strong, nonatomic) NSString *savePath;
// 该初始化方法中，如果path指定的文件存在，则会先删除该文件然后创建一个新的
- (id)initWithPath:(NSString*)path;
// 用initWithPath 的对象，则用下面两个函数写入数据
- (void)deletePath;
- (void)writeDataBytes:(Byte*)dBytes len:(NSInteger)len;
- (void)writeData:(NSData*)data;

// 用【[alloc] init] 的方式初始化的对象，则用下面三个函数操作
- (void)deletePath:(NSString*)path;
- (void)writeDataBytes:(Byte*)dBytes len:(NSInteger)len toPath:(NSString *)savePath;
- (void)writeData:(NSData*)data toPath:(NSString *)savePath;
@end

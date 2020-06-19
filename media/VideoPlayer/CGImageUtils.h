//
//  CGImageUtils.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/1.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CGImageUtils : NSObject

/** 基于IOS CoreGraphics的图片解码
 *  1、它是用CPU的软解码
 *  2、解码后，最终是RGBA排列格式的像素数据
 *  3、每一个通道占8位，一个像素占用四个字节
 *  name:图片的路径
 *  orgWidth:解码后将宽度返回
 *  orgHeight:解码后将高度返回
 */
+ (void*)rgbaImageDataForPath:(NSString*)name width:(int*)orgwidth height:(int*)orgheight;

+ (void)pngToJPGWithPath:(NSString*)pngPath tojpgPath:(NSString*)jpgPath;

+ (UIImage*)rgga8bitsPixelDataToUIImage:(void*)pixelData width:(int)pixwidth height:(int)pixheight;
+ (void)rgga8bitsPixelDataToUIImageThenSave:(void*)pixelData width:(int)pixwidth height:(int)pixheight toPath:(NSString*)path;

@end


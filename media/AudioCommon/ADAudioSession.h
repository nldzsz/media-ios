//
//  ADAudioSession.h
//  media
//
//  Created by Owen on 2019/5/19.
//  Copyright © 2019 Owen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ADAudioDefine.h"

/** 该类是对AVAudioSession的封装
 *
 */
@interface ADAudioSession : NSObject

@property (strong, nonatomic) AVAudioSession *aSession;
@property (assign, nonatomic) CGFloat   currentSampleRate;
@property (assign, nonatomic) NSInteger currentChannels;

@property (assign, nonatomic) ADAudioFormatType formatType;
@property (assign, nonatomic) ADAudioSaveType   saveType;
@property (assign, nonatomic) BOOL bigEndian;

-(instancetype)initWithCategary:(AVAudioSessionCategory)category
                       channels:(NSInteger)chs
                     sampleRate:(double)rate
                 bufferDuration:(NSTimeInterval)duration
                    fortmatType:(ADAudioFormatType)formatType
                       saveType:(ADAudioSaveType)saveType;

-(instancetype)initWithCategary:(AVAudioSessionCategory)category
                       channels:(NSInteger)chs
                     sampleRate:(double)rate
                 bufferDuration:(NSTimeInterval)duration
                    fortmatType:(ADAudioFormatType)formatType
                       saveType:(ADAudioSaveType)saveType
                    isBigEndian:(BOOL)bigEndian;


// 是否planner 存储方式
- (BOOL)isPlanner;
- (AudioFormatFlags)formatFlags;
- (NSInteger)bytesPerChannel;
@end

//
//  AudioUnitGenericOutput.h
//  media
//
//  Created by 飞拍科技 on 2019/7/10.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommon.h"
#import "ADExtAudioFile.h"
#import "AudioDataWriter.h"

/** 用来学习离线音频处理，什么叫离线音频处理，就是音频的最终不是输出给扬声器而是输出给应用端
 */
@interface AudioUnitGenericOutput : NSObject
{
    AUGraph                     _auGraph;
    
    AUNode                      _genericNode;
    AudioUnit                   _genericUnit;
    
    AUNode                      _source1Node;
    AudioUnit                   _source1Unit;
    
    AUNode                      _source2Node;
    AudioUnit                   _source2Unit;
    
    AUNode                      _mixerNode;
    AudioUnit                   _mixerUnit;
    
    AudioFileID                 _source1FileID;
    AudioFileID                 _source2FileID;
    
    BOOL                        _offlineRun;
    ADExtAudioFile              *_extFileWriter;
    // 用于写裸PCM数据到音频文件中
    AudioDataWriter             *_dataWriteForPCM;
    AudioStreamBasicDescription _clientABSD;
    float                       _volume[2];
    UInt32                      _totalFrames;
}
@property (strong, nonatomic) NSString *source1;
@property (strong, nonatomic) NSString *source2;
@property (copy, nonatomic) void (^completeBlock)(void);

- (id)initWithPath1:(NSString*)path1 volume:(float)vol1 path2:(NSString*)path2 volume:(float)vol2;
- (void)setupFormat:(ADAudioFormatType)format
      audioSaveType:(ADAudioSaveType)saveType
         sampleRate:(UInt32)samplerate
           channels:(UInt32)channels
           savePath:(NSString*)savePath
       saveFileType:(ADAudioFileType)type;


- (void)start;
- (void)stop;
@end

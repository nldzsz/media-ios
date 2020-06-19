//
//  CommonFunction.m
//  media
//
//  Created by 飞拍科技 on 2019/7/11.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "CommonFunction.h"

void CheckStatusReturn(OSStatus status,NSString *log)
{
    NSString *strLog = @"noErr";
    switch (status) {
        case kAudioUnitErr_InvalidProperty:
            strLog = @"kAudioUnitErr_InvalidProperty           = -10879";
            break;
        case kAudioUnitErr_InvalidParameter:
            strLog = @"kAudioUnitErr_InvalidParameter          = -10878";
            break;
        case kAudioUnitErr_InvalidElement:
            strLog = @"kAudioUnitErr_InvalidElement            = -10877";
            break;
        case kAudioUnitErr_NoConnection:
            strLog = @"kAudioUnitErr_NoConnection              = -10876";
            break;
        case kAudioUnitErr_FailedInitialization:
            strLog = @"kAudioUnitErr_FailedInitialization      = -10875";
            break;
        case kAudioUnitErr_TooManyFramesToProcess:
            strLog = @"kAudioUnitErr_TooManyFramesToProcess    = -10874";
            break;
        case kAudioUnitErr_InvalidFile:
            strLog = @"kAudioUnitErr_InvalidFile               = -10871";
            break;
        case kAudioUnitErr_UnknownFileType:
            strLog = @"kAudioUnitErr_UnknownFileType           = -10870";
            break;
        case kAudioUnitErr_FileNotSpecified:
            strLog = @"kAudioUnitErr_FileNotSpecified          = -10869";
            break;
        case kAudioUnitErr_FormatNotSupported:
            strLog = @"kAudioUnitErr_FormatNotSupported        = -10868";
            break;
        case kAudioUnitErr_Uninitialized:
            strLog = @"kAudioUnitErr_Uninitialized             = -10867";
            break;
        case kAudioUnitErr_InvalidScope:
            strLog = @"kAudioUnitErr_InvalidScope              = -10866";
            break;
        case kAudioUnitErr_PropertyNotWritable:
            strLog = @"kAudioUnitErr_PropertyNotWritable       = -10865";
            break;
        case kAudioUnitErr_CannotDoInCurrentContext:
            strLog = @"kAudioUnitErr_CannotDoInCurrentContext  = -10863";
            break;
        case kAudioUnitErr_InvalidPropertyValue:
            strLog = @"kAudioUnitErr_InvalidPropertyValue      = -10851";
            break;
        case kAudioUnitErr_PropertyNotInUse:
            strLog = @"kAudioUnitErr_PropertyNotInUse          = -10850";
            break;
        case kAudioUnitErr_Initialized:
            strLog = @"kAudioUnitErr_Initialized               = -10849";
            break;
        case kAudioUnitErr_InvalidOfflineRender:
            strLog = @"kAudioUnitErr_InvalidOfflineRender      = -10848";
            break;
        case kAudioUnitErr_Unauthorized:
            strLog = @"kAudioUnitErr_Unauthorized              = -10847";
            break;
        case kAudioUnitErr_MIDIOutputBufferFull:
            strLog = @"kAudioUnitErr_MIDIOutputBufferFull      = -66753";
            break;
        case kAudioComponentErr_InstanceTimedOut:
            strLog = @"kAudioComponentErr_InstanceTimedOut     = -66754";
            break;
        case kAudioComponentErr_InstanceInvalidated:
            strLog = @"kAudioComponentErr_InstanceInvalidated  = -66749";
            break;
        case kAudioUnitErr_RenderTimeout:
            strLog = @"kAudioUnitErr_RenderTimeout             = -66745";
            break;
        case kAudioUnitErr_ExtensionNotFound:
            strLog = @"kAudioUnitErr_ExtensionNotFound         = -66744";
            break;
        case kAudioUnitErr_InvalidParameterValue:
            strLog = @"kAudioUnitErr_InvalidParameterValue     = -66743";
            break;
        case noErr:
            strLog = @"noErr";
            break;
        default:
            strLog = [NSString stringWithFormat:@"unknow %d",status];
            break;
    }
    if(status != noErr) {
        NSLog(@"%@ error: %@",log,strLog);
    }
}


//
//  AVAudioSession+extion.h
//  media
//
//  Created by Owen on 2019/5/19.
//  Copyright © 2019 Owen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVAudioSession (extion)
- (BOOL)usingBlueTooth;
- (BOOL)usingWiredMicrophone;
- (BOOL)shouldShowEarphoneAlert;
@end

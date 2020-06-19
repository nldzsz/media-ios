//
//  GLVideoView.h
//  media
//
//  Created by 飞拍科技 on 2019/6/8.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GLDefine.h"

@interface GLVideoView : UIView

- (void)rendyuvFrame:(VideoFrame*)yuvFrame;

- (void)releaseSources;
@end

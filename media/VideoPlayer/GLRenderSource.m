//
//  GLRenderSource.m
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "GLRenderSource.h"

@implementation GLRenderSource
- (id)initWithContext:(GLContext*)context
{
    if (self = [super init]) {
        self.context = context;
        renderTargets = [NSMutableArray array];
    }
    
    return self;
}

- (void)addTarget:(id<GLRenderSourceInput>)source
{
    if ([renderTargets containsObject:source]) {
        return;
    }
    
    [renderTargets addObject:source];
}
- (void)removeAllTargets
{
    [renderTargets removeAllObjects];
}

- (void)destroy
{
    [outputFramebuffer destroyFramebuffer];
}
- (void)dealloc
{
    [self destroy];
}

- (void)notifyRenderFinish
{
    for (id<GLRenderSourceInput>input in renderTargets) {
        [input renderFinishAtBuffer:outputFramebuffer];
    }
}

- (void)renderToScreen
{
    [self.context useAsCurrentContext];
    [self.context presentForDisplay];
}

- (void)removeOutputframebuffer
{
    [outputFramebuffer destroyFramebuffer];
    outputFramebuffer = nil;
}
- (GLFrameBuffer*)outputFramebuffer
{
    return outputFramebuffer;
}
@end

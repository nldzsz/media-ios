//
//  FFmpegEnDecodeViewController.m
//  media
//
//  Created by 飞拍科技 on 2019/8/9.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "FFmpegEnDecodeViewController.h"
#import "VideoDecoder.h"
#import "SFVideoEncoder.h"
#import "TestAVPacket.h"
#import "TestMuxer.h"

@interface FFmpegEnDecodeViewController ()

@end

@implementation FFmpegEnDecodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *btn1 = [UIButton buttonWithType:UIButtonTypeSystem];
    btn1.frame = CGRectMake(130, 100, 150, 30);
    [btn1 setTitle:@"测试AVPacket" forState:UIControlStateNormal];
    [self.view addSubview:btn1];
    [btn1 addTarget:self action:@selector(testAVPacket) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.frame = CGRectMake(20, 60, 50, 50);
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [self.view addSubview:backBtn];
    [backBtn addTarget:self action:@selector(onTapBackBtn:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)onTapBackBtn:(UIButton*)btn
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)testAVPacket
{
//    [TestAVPacket testAVPacket];
//    [TestAVPacket testAVFrame];
//    VideoDecoder *decoder = [[VideoDecoder alloc] init];
//    [decoder test];
//
//    VideoEncoder *encoder = [[VideoEncoder alloc] init];
//    [encoder test];
    
//    [TestMuxer testMuxer];
}


@end

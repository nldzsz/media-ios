//
//  VideoPlayerViewController.m
//  media
//
//  Created by 飞拍科技 on 2019/6/24.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "VideoPlayerViewController.h"
#import "YuvPlayer.h"

@interface VideoPlayerViewController ()
@property(nonatomic,strong)VideoFileSource *source;
@end

@implementation VideoPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 310, 200, 50)];
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [self.view addSubview:backBtn];
    [backBtn addTarget:self action:@selector(onTapBackBtn:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)onTapBackBtn:(UIButton*)btn
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // ======= 播放yuv视频  =========== //
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(25, 10, 640, 320)];
    view.backgroundColor = [UIColor redColor];
    [self.view addSubview:view];
    
    // 初始化播放器
    YuvPlayer *player = [YuvPlayer shareInstance];
    [player setVideoView:view];
    [player play];
    
    // 初始化视频源
    NSString *lpath = [[NSBundle mainBundle] pathForResource:@"test-420P-320x160" ofType:@"yuv"];
    NSURL *fileUrl = [NSURL fileURLWithPath:lpath];
    self.source = [[VideoFileSource alloc] initWithFileUrl:fileUrl];
    self.source.delegate = player;
    [self.source setVideoWidth:320 height:160];
    [self.source beginPullVideo];
    // ======= 播放yuv视频  =========== //
}
@end

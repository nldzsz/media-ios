//
//  AudioPlayerViewController.m
//  media
//
//  Created by 飞拍科技 on 2019/6/24.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "AudioPlayerViewController.h"
#import "ADAudioUnitPlay.h"
#import "ADAVPlayer.h"
#import "ADAVAudioPlayer.h"
#import "BaseUnitPlayer.h"
#import "VideoFileSource.h"

typedef void(^Study)(void);
@interface Student : NSObject
@property (copy , nonatomic) NSString *name;
@property (copy , nonatomic) Study study;
@end

@implementation Student

- (void)dealloc
{
    NSLog(@"Student dealloc");
}
@end

@interface AudioPlayerViewController ()
@property (strong, nonatomic) ADAudioUnitPlay *unitPlay;
@property (strong, nonatomic) BaseUnitPlayer  *basePlay;
@property (strong, nonatomic) ADAVAudioPlayer *audioPlayer;
@property (strong, nonatomic) ADAVPlayer *avPlayer;

@property (strong, nonatomic) Student *stu;
@property (copy,nonatomic) NSString *name;
@end

@implementation AudioPlayerViewController

- (void)dealloc
{
    NSLog(@"AudioPlayerViewController dealloc");
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    Student *student = [[Student alloc] init];
    
    self.name = @"halfrost";
    self.stu = student;
    
    __weak typeof(self)weakSelf = self;
    student.study = ^{
        NSLog(@"my name is = %@",weakSelf.name);    // 不会循环引用
//        NSLog(@"my name is = %@",self.name);        // 循环引用
    };
    
    student.study();
    
//    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(100, 200, 200, 50)];
    [btn setTitle:@"AVAudioPlayer 播放音频" forState:UIControlStateNormal];
    [self.view addSubview:btn];
    [btn addTarget:self action:@selector(playByAVAudioPlayer) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btn1 = [[UIButton alloc] initWithFrame:CGRectMake(100, 260, 200, 50)];
    [btn1 setTitle:@"AVPlayer 播放音频" forState:UIControlStateNormal];
    [self.view addSubview:btn1];
    [btn1 addTarget:self action:@selector(playByAVPlayer) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btn2 = [[UIButton alloc] initWithFrame:CGRectMake(100, 310, 200, 50)];
    [btn2 setTitle:@"AudioUnitPlay 播放音频" forState:UIControlStateNormal];
    [self.view addSubview:btn2];
    [btn2 addTarget:self action:@selector(playPCM) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, 60, 200, 50)];
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [self.view addSubview:backBtn];
    [backBtn addTarget:self action:@selector(onTapBackBtn:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)onTapBackBtn:(UIButton*)btn
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playByAVAudioPlayer
{
    self.audioPlayer = [[ADAVAudioPlayer alloc] init];
    NSString *lpath = [[NSBundle mainBundle] pathForResource:@"test-mp3-1" ofType:@"mp3"];
    [self.audioPlayer initWithPath:lpath];
    [self.audioPlayer play];
}

- (void)playByAVPlayer
{
    self.avPlayer = [[ADAVPlayer alloc] init];
    
    // 注意如果是本地的这里要用fileURLWithxxx；远程的则用urlWithxxx，否则url协议解析会出错
    // 可以播放远程在线文件
    NSString *rPath = @"https://img.flypie.net/test-mp3-1.mp3";
    NSURL *remoteUrl = [NSURL URLWithString:rPath];
    
    // 本地文件
    NSString *lpath = [[NSBundle mainBundle] pathForResource:@"test-mp3-1" ofType:@"mp3"];
    NSURL *localUrl = [NSURL URLWithString:lpath];
    
    [self.avPlayer initWithURL:remoteUrl];
    [self.avPlayer play];
}

- (void)playPCM
{
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    path = [path stringByAppendingPathComponent:@"test.PCM"];
//        NSString *l1path = [[NSBundle mainBundle] pathForResource:@"test_441_f32le_2" ofType:@"pcm"];
//    NSString *l1path = [[NSBundle mainBundle] pathForResource:@"test_441_s16le_2" ofType:@"amr"];
    
        self.basePlay = [[BaseUnitPlayer alloc] initWithChannels:2 sampleRate:44100 format:ADAudioFormatType32Float path:path];
        [self.basePlay play];
    
//        self.unitPlay = [[ADAudioUnitPlay alloc] initWithChannels:2 sampleRate:44100 formatType:ADAudioFormatType32Float planner:YES path:path];
//    self.unitPlay = [[ADAudioUnitPlay alloc] initWithChannels:2 sampleRate:44100 format:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked path:l1path];
//    [self.unitPlay play];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

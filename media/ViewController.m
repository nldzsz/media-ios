//
//  ViewController.m
//  media
//
//  Created by Owen on 2019/5/14.
//  Copyright © 2019 Owen. All rights reserved.
//

#import "ViewController.h"
#import "Activities/AudioPlayerViewController.h"
#import "Activities/VideoPlayerViewController.h"
#import "Activities/AudioRecorderViewController.h"
#import "AudioEnDecodeViewController.h"
#import "VideoRecordController.h"
#import "FFmpegEnDecodeViewController.h"

@interface ViewController ()

- (IBAction)audioPlay:(id)sender;
- (IBAction)videoPlay:(id)sender;
- (IBAction)audioRecord:(id)sender;
- (IBAction)videoRecord:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (IBAction)audioPlay:(id)sender {
    AudioPlayerViewController *vc = [[AudioPlayerViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)videoPlay:(id)sender {
    VideoPlayerViewController *vc = [[VideoPlayerViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)audioRecord:(id)sender {
    AudioRecorderViewController *vc = [[AudioRecorderViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)videoRecord:(id)sender {
    VideoRecordController *vc = [[VideoRecordController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)encodeAndDecode:(id)sender {
    AudioEnDecodeViewController *vc = [[AudioEnDecodeViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}
- (IBAction)ffmpegEnDecode:(id)sender {
    FFmpegEnDecodeViewController *vc = [[FFmpegEnDecodeViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}
@end

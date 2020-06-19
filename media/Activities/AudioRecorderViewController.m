//
//  AudioRecorderViewController.m
//  media
//
//  Created by 飞拍科技 on 2019/6/24.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "AudioRecorderViewController.h"
#import "AudioUnitRecorder.h"
#import "AudioUnitGenericOutput.h"
#import "ADAudioUnitPlay.h"
#import "EBDropdownList/EBDropdownListView.h"

@interface AudioRecorderViewController ()
{
    BOOL isRecording;
    BOOL isPlaying;
    NSString *_audioPath;
    NSString *_audioPath2;
    
    ADAudioFormatType   _formatType;
    ADAudioFileType     _saveFileType;
    BOOL                _planner;
    BOOL                _recordAndPlay;
    CGFloat             _sampleRate;
    NSInteger           _channels;
    
    
    EBDropdownListView *_dropdownListView;
    
}
@property (strong, nonatomic) AudioUnitRecorder *audioUnitRecorder;
@property (strong, nonatomic) AudioUnitGenericOutput *audioGenericOutput;
@property (strong, nonatomic) ADAudioUnitPlay *audioUnitPlay;
@property (strong, nonatomic) UIButton *recordBtn;
@property (strong, nonatomic) UIButton *playBtn;

@property (strong, nonatomic) UILabel *statusLabel;
@end

@implementation AudioRecorderViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.recordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.recordBtn.frame = CGRectMake(150, 200, 100, 50);
    [self.recordBtn setTitle:@"开始" forState:UIControlStateNormal];
    [self.view addSubview:self.recordBtn];
    [self.recordBtn addTarget:self action:@selector(onTapRecordBtn:) forControlEvents:UIControlEventTouchUpInside];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 150, 100, 50)];
    self.statusLabel.text = @"";
    [self.view addSubview:self.statusLabel];
    
    self.playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playBtn.frame = CGRectMake(150, 270,100, 50);
    [self.playBtn setTitle:@"播放录音" forState:UIControlStateNormal];
    [self.view addSubview:self.playBtn];
    [self.playBtn addTarget:self action:@selector(onTapPlayBtn:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.frame = CGRectMake(20, 50, 50, 50);
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [self.view addSubview:backBtn];
    [backBtn addTarget:self action:@selector(onTapBackBtn:) forControlEvents:UIControlEventTouchUpInside];
    
    
    EBDropdownListItem *item1 = [[EBDropdownListItem alloc] initWithItem:@"1" itemName:@"录制+存储为PCM"];
    EBDropdownListItem *item2 = [[EBDropdownListItem alloc] initWithItem:@"2" itemName:@"录制+耳返存储为PCM"];
    EBDropdownListItem *item3 = [[EBDropdownListItem alloc] initWithItem:@"3" itemName:@"录制+存储为M4A/CAF/WAV"];
    EBDropdownListItem *item4 = [[EBDropdownListItem alloc] initWithItem:@"4" itemName:@"录制+耳返并播放背景音乐"];
    EBDropdownListItem *item5 = [[EBDropdownListItem alloc] initWithItem:@"5" itemName:@"离线混合音频文件"];
    EBDropdownListItem *item6 = [[EBDropdownListItem alloc] initWithItem:@"6" itemName:@"录制+添加背景音乐"];
    _dropdownListView = [[EBDropdownListView alloc] initWithDataSource:@[item1, item2,item3,item4,item5,item6]];
    _dropdownListView.selectedIndex = 0;
    _dropdownListView.frame = CGRectMake(20, 100, 330, 30);
    [_dropdownListView setViewBorder:0.5 borderColor:[UIColor grayColor] cornerRadius:2];
    [self.view addSubview:_dropdownListView];
    
    __weak typeof(self)weakSelf = self;
    [_dropdownListView setDropdownListViewSelectedBlock:^(EBDropdownListView *dropdownListView) {
        [weakSelf stopRecord];
        [weakSelf stopPlay];
        
        [weakSelf.recordBtn setTitle:@"开始" forState:UIControlStateNormal];
        [weakSelf.playBtn setTitle:@"开始播放" forState:UIControlStateNormal];
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)onTapBackBtn:(UIButton*)btn
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)stopRecord
{
    isRecording = NO;
    if (self.audioUnitRecorder) {
        [self.audioUnitRecorder stopRecord];
        self.audioUnitRecorder = nil;
    }
    [self.recordBtn setTitle:@"开始" forState:UIControlStateNormal];
}
- (void)onTapRecordBtn:(UIButton*)btn
{
    if (isRecording) {  // 正在录音
        isRecording = NO;
        [self stopRecord];
        [self stopPlay];
        
        NSInteger _selectIndex = _dropdownListView.selectedIndex;
        if (_selectIndex == 5) {        // 还添加背景音乐
            if (self.audioGenericOutput) {
                [self.audioGenericOutput stop];
                self.audioGenericOutput = nil;
            }

            NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
            _audioPath2 = [path stringByAppendingPathComponent:@"test_back_mixer.PCM"];
            self.audioUnitRecorder = nil;

            _saveFileType = ADAudioFileTypeLPCM;

            // 由于AudioFilePlayer无法读取PCM裸数据文件，所以这里用MP3
            NSString *file1 = [[NSBundle mainBundle] pathForResource:@"background" ofType:@"mp3"];
            self.audioGenericOutput = [[AudioUnitGenericOutput alloc] initWithPath1:file1 volume:0.1 path2:_audioPath volume:0.9];
            [self.audioGenericOutput setupFormat:_formatType audioSaveType:_planner?ADAudioSaveTypePlanner:ADAudioSaveTypePacket sampleRate:_sampleRate channels:_channels savePath:_audioPath2 saveFileType:_saveFileType];
            NSTimeInterval timeBegin = [NSDate timeIntervalSinceReferenceDate];
            NSLog(@"开始渲染 .....");
            __weak typeof(self)weakSelf = self;
            self.audioGenericOutput.completeBlock = ^{
                NSLog(@"渲染结束 耗时 %.2f ",[NSDate timeIntervalSinceReferenceDate] - timeBegin);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf stopPlay];
                    [weakSelf stopRecord];
                });
            };
            [self.audioGenericOutput start];
        }
    } else {
        isRecording = YES;
        isPlaying = NO;
        if (self.audioUnitRecorder != nil) {
            [self.audioUnitRecorder stopRecord];
            self.audioUnitRecorder = nil;
        }
        if (self.audioUnitPlay != nil) {
            [self.audioUnitPlay stop];
            self.audioUnitPlay = nil;
        }
        
        _formatType = ADAudioFormatType16Int;
        _sampleRate = 44100;
        _channels = 2;
        _planner = YES;
        
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSInteger _selectIndex = _dropdownListView.selectedIndex;
        if (_selectIndex == 0) {
            // 存储的裸PCM数据
            _audioPath = [path stringByAppendingPathComponent:@"test.PCM"];
            NSLog(@"文件目录 ==>%@",_audioPath);
            _saveFileType = ADAudioFileTypeLPCM;
            _recordAndPlay = NO;
            self.audioUnitRecorder = [[AudioUnitRecorder alloc] initWithFormatType:_formatType planner:_planner channels:_channels samplerate:_sampleRate Path:_audioPath saveFileType:_saveFileType];
            
            [self.audioUnitRecorder startRecord];
        }
        else if(_selectIndex == 1){
            _audioPath = [path stringByAppendingPathComponent:@"test.PCM"];
            NSLog(@"文件目录 ==>%@",_audioPath);
            _saveFileType = ADAudioFileTypeLPCM;
            _recordAndPlay = YES;
            self.audioUnitRecorder = [[AudioUnitRecorder alloc] initWithFormatType:_formatType planner:_planner channels:_channels samplerate:_sampleRate Path:_audioPath recordAndPlay:_recordAndPlay saveFileType:_saveFileType];
            
            [self.audioUnitRecorder startRecord];
        }
        else if(_selectIndex == 2){
            // 保存的封装格式 要对应
            _audioPath = [path stringByAppendingPathComponent:@"test.m4a"];
            NSLog(@"文件目录 ==>%@",_audioPath);
            
            _saveFileType = ADAudioFileTypeM4A;
            _recordAndPlay = NO;
            self.audioUnitRecorder = [[AudioUnitRecorder alloc] initWithFormatType:_formatType planner:_planner channels:_channels samplerate:_sampleRate Path:_audioPath recordAndPlay:_recordAndPlay saveFileType:_saveFileType];
            
            [self.audioUnitRecorder startRecord];
        }
        else if(_selectIndex == 3){
            // 录制 播放背景音乐 并且有耳返效果;path 为nil 则不保存录制的音频
            _recordAndPlay = YES;
            NSString *file = [[NSBundle mainBundle] pathForResource:@"background" ofType:@"mp3"];
            self.audioUnitRecorder = [[AudioUnitRecorder alloc] initWithFormatType:_formatType planner:_planner channels:_channels samplerate:_sampleRate Path:nil backgroundMusicPath:file recordAndPlay:YES saveFileType:_saveFileType];
            
            [self.audioUnitRecorder startRecord];
        }
        else if(_selectIndex == 4){
            if (self.audioGenericOutput) {
                [self.audioGenericOutput stop];
                self.audioGenericOutput = nil;
            }
            // 保存的封装格式 要对应
            _audioPath = [path stringByAppendingPathComponent:@"test-mixer.m4a"];
            NSLog(@"文件目录 ==>%@",_audioPath);
            
            _saveFileType = ADAudioFileTypeM4A;
            _recordAndPlay = NO;
            
            // 由于AudioFilePlayer无法读取PCM裸数据文件，所以这里用MP3
            NSString *file1 = [[NSBundle mainBundle] pathForResource:@"background" ofType:@"mp3"];
            NSString *file2 = [[NSBundle mainBundle] pathForResource:@"test-mp3-1" ofType:@"mp3"];
            self.audioGenericOutput = [[AudioUnitGenericOutput alloc] initWithPath1:file1 volume:0.1 path2:file2 volume:0.9];
            [self.audioGenericOutput setupFormat:ADAudioFormatType16Int audioSaveType:ADAudioSaveTypePlanner sampleRate:44100 channels:2 savePath:_audioPath saveFileType:_saveFileType];
            NSTimeInterval timeBegin = [NSDate timeIntervalSinceReferenceDate];
            NSLog(@"开始渲染 .....");
            __weak typeof(self)weakSelf = self;
            self.audioGenericOutput.completeBlock = ^{
                NSLog(@"渲染结束 耗时 %.2f ",[NSDate timeIntervalSinceReferenceDate] - timeBegin);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf stopPlay];
                    [weakSelf stopRecord];
                });
            };
            [self.audioGenericOutput start];
        }
        else if(_selectIndex == 5){
            // 保存的封装格式 要对应
            _audioPath = [path stringByAppendingPathComponent:@"test.m4a"];
            NSLog(@"文件目录 ==>%@",_audioPath);
            
            _saveFileType = ADAudioFileTypeM4A;
            _recordAndPlay = NO;
            
            NSString *file = [[NSBundle mainBundle] pathForResource:@"background" ofType:@"mp3"];
            self.audioUnitRecorder = [[AudioUnitRecorder alloc] initWithFormatType:_formatType planner:_planner channels:_channels samplerate:_sampleRate Path:_audioPath backgroundMusicPath:file recordAndPlay:_recordAndPlay saveFileType:_saveFileType];
            
            [self.audioUnitRecorder startRecord];
        }
        
        [self.recordBtn setTitle:@"停止" forState:UIControlStateNormal];
    }
}

- (void)onTapPlayBtn:(UIButton*)btn
{
    [self stopRecord];
    
    /** 遇到问题：录制的kAudioFormatFlagIsSignedInteger的音频接着在播放，无法正常播放
     *  解决方案：ios只支持16位整形和32位浮点型的播放，所以所以播放格式设置正确即可
     */
    if (!isPlaying) {
        isPlaying = YES;
        if (self.audioUnitPlay) {
            [self.audioUnitPlay stop];
            self.audioUnitPlay = nil;
        }
        
        if (_saveFileType == ADAudioFileTypeLPCM) {
            NSInteger _selectIndex = _dropdownListView.selectedIndex;
            if (_selectIndex == 5) {   // 播放方式不一样
                self.audioUnitPlay = [[ADAudioUnitPlay alloc] initWithChannels:_channels sampleRate:_sampleRate formatType:_formatType planner:_planner path:_audioPath2];
            } else {
                self.audioUnitPlay = [[ADAudioUnitPlay alloc] initWithChannels:_channels sampleRate:_sampleRate formatType:_formatType planner:_planner path:_audioPath];
            }
        } else {
            NSInteger _selectIndex = _dropdownListView.selectedIndex;
            if (_selectIndex == 5) {        // 还添加背景音乐
                self.audioUnitPlay = [[ADAudioUnitPlay alloc] initWithAudioFilePath:_audioPath2 fileType:_saveFileType];
            } else {
                self.audioUnitPlay = [[ADAudioUnitPlay alloc] initWithAudioFilePath:_audioPath fileType:_saveFileType];
            }
        }
        
        [self.audioUnitPlay play];
        
        [self.playBtn setTitle:@"停止播放" forState:UIControlStateNormal];
    } else {    // 正在播放
        [self stopPlay];
    }
}

- (void)stopPlay
{
    isPlaying = NO;
    if (self.audioUnitPlay) {
        [self.audioUnitPlay stop];
        self.audioUnitPlay = nil;
    }
    [self.playBtn setTitle:@"开始播放" forState:UIControlStateNormal];
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

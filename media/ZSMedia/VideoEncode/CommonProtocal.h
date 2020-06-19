//
//  CommonProtocal.h
//  media
//
//  Created by apple on 2020/6/17.
//  Copyright © 2020 飞拍科技. All rights reserved.
//

#ifndef CommonProtocal_h
#define CommonProtocal_h

/** 编码相关回调及相关参数
 */
@protocol VideoEncodeDelegate <NSObject>

// ========= 保存h264码流 ========= //
// 编码后是否保存为h264码流
@property(nonatomic,assign)BOOL enableWriteToh264;
// 如果保存 h264的保存路径
@property(nonatomic,strong)NSString *h264FilePath;
// ========= 保存h264码流 ========= //

// todo:回调方法负责packet内存的管理和回收
- (void)didEncodeSucess:(VideoPacket*)packet;
- (void)didEncodeFail:(NSError*)error;

@end

/** 编码接口的封装；统一软编码以及硬编码调用接口
 */
@protocol VideoEncodeProtocal <NSObject>

/** 设置编码相关参数
 */
- (void)setParameters:(VideoCodecParameter*)param;

/** 将未压缩数据送入编码器缓冲区开始编码，编码器会先缓冲数帧然后开始编码，缓冲数目与GOP大小有关
 *  1、编码回调协议中的方法didEncodeSucess:、VideoEncodeDelegate与此方法在同一线程
 *  2、该方法非线程安全的，如果在不同线程中调用此方法会造成不可预知问题
 */
- (void)encodeRawVideo:(VideoFrame*)yuvframe;

/** 将编码器缓冲区中还有未编码的数据，全部编码完成，然后释放编码器相关资源
 *  1、编码回调协议中的方法didEncodeSucess:、VideoEncodeDelegate与此方法在同一线程
 *  2、调用此方法后就不能再调用encodeRawVideo方法了
 *  3、非线程安全的，此方法要和encodeRawVideo在同一线程调用，否则会造成无法预知问题
 */
- (void)flushEncode;

/** 关闭编码器；
 *  1、如果编码器缓冲区中含有未编码完的数据，该方法调用后将清除这部分数据，然后立即停止编码工作和释放编码器相关工作
 *  2、如果此方法要和encodeRawVideo方法在不同一线程中调用，这样才会立即停止编码工作，否则会等待剩余编码工作全部结束才返回
 */
- (void)closeEncoder;

@end

#endif /* CommonProtocal_h */

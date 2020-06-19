//
//  VideoH264Encoder.hpp
//  media
//
//  Created by 飞拍科技 on 2019/8/12.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef VideoH264Encoder_hpp
#define VideoH264Encoder_hpp

#include "CodecBase.hpp"
#include "MZCommonDefine.h"
#include "VideoParameters.hpp"
#include <pthread.h>

class VideoH264Encoder:public CodecBase
{
public:
    VideoH264Encoder();
    VideoH264Encoder(const VideoParameters& parameters);
    ~VideoH264Encoder();
    
    // 设置编码相关参数
    void setParameters(VideoParameters parameters);
    
    // 并开启编码器;true 成功开启，接下来就可以调用编码相关函数;false 开启失败
    bool openEncoder();
    // 编码器是否打开;打开编码器之后才可以调用编码相关函数
    bool canUseEncoder();
    
    typedef void EncodeCallback(void* client,VideoPacket *packet);
    // 编码成功后的回调函数
    void setEncodeCallback(void*client,EncodeCallback *callback);
    // 编码相关函数;
    void sendRawVideoAndReceivePacketVideo(VideoFrame *frame);
    
    // === 线程安全的 ==== //
    // 编码相关函数
    void safeSendRawVideoFrame(VideoFrame *frame);
    // 获取编码后的结果
    bool safeReceiveEncodedFrame(VideoPacket *packet);
    // === 线程安全的 ==== //
    
    // !!!!清空并释放编码器内资源；在所有编码数据发送完毕后，必须要调用一下此方法才能获取所有的编码的数据；否则无法获取所有编码数据，
    // 而且可能会造成内存没有及时释放的问题
    void flushEncoder();
    
    // 关闭编码器，终止编码工作；再其它线程调用
    void closeEncoder();
    
private:
    VideoParameters    fParameters;
    EncodeCallback          *fEncodeCallback;
    void                    *fEncodeClient;
    // 检验参数的合法性
    bool checkParametersValidate(VideoParameters parameters);
    void resetFrame();
    
    bool fOpenedEncoder;
    long long fFramecount;  // 编码数量
    
    // 执行编码
    void doEncode(AVFrame *frame);
    // 内部释放资源
    void internalRelase();
};
#endif /* VideoEncoder_hpp */

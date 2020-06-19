//
//  TestFFmpeg.m
//  media
//
//  Created by apple on 2019/8/22.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "TestAVPacket.h"
extern "C" {
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/imgutils.h"
}

@implementation TestAVPacket
+ (void)testAVPacket
{
    // AVPacket 位于libavcodec/avcodec.h中
    // 引用计数方式创建AVPacket
    /** av_init_packet();av_packet_alloc只是为AVPacket结构体赋予初值，里面的data,buf,side_data等都为NULL
     *  其它成员的值也都是默认的值
     *  av_new_packet();则先根据size的大小为buf分配内存(因为字节对齐实际大小分配内存大小可能会大于传入的size)，然后将buf的data指向内存地址
     *  赋值给data，同时AVPacket的引用计数为1。
     *  av_packet_unref();将AVPacket的引用计数减1，如果引用计数为0，则会释放buf以及data所指向内存，并将这两个字段置为NULL
     */
    /** AVPacket是否可写：buf不为空，并且对应的flags非AV_BUFFER_FLAG_READONLY
     *  av_packet_make_writable()，首先判断是否可写，不可写则重新创建buf，并将data指向内存拷贝到buf中，将引用计数设置为1
     *  av_packet_make_refcounted(),如果没有buf字段或者buf的大小与AVPacket的sizeb不相同，则会重新创建buf字段，则重新创建buf
     *  并将data指向内存拷贝到buf中，将引用计数设置为1
     *  tips：AVPacket对象如果由av_packet_free()等函数释放了，则不能调用此函数了，会奔溃
     */
    
    
    //  ====== 正确的使用方式 一 ====== //
    // 在堆内存创建AVPacket对象，初始化为默认值，data,buf,side_data等都为NULL，它内部会调用av_init_packet()方法
    AVPacket *allocpkt = av_packet_alloc();
    
    // 为buf分配内存，并且将data指向该内存，并且将引用计数设置为1
    av_new_packet(allocpkt, 200);
    // 引用计数减少1；如果引用计数为0，data内存将在此函数中释放，并且data和buf字段都置为NULL
    av_packet_unref(allocpkt);
    // 由av_packet_alloc()创建的AVPacket最后还必须要用av_packet_free()来释放，调用此函数后allocpkt将置为NULL;
    // 内部会调用一次av_packet_unref()
    av_packet_free(&allocpkt);
    //  ====== 正确的使用方式 一 ====== //
    
    //  ====== 正确的使用方式 二 ====== //
    // 栈内存创建AVPacket对象，按栈内存方式初始化AVPacket的值(所有的值)
    AVPacket initpkt;
    // 初始化AVPacket的值为默认值，data,buf,side_data等都为NULL
    av_init_packet(&initpkt);
    // 分配data内存，并将引用计数设置为1
    av_new_packet(&initpkt, 100);
    // 引用计数减少1；如果引用计数为0，data内存将在此函数中释放，并且data和buf字段都置为NULL
    av_packet_unref(&initpkt);
    // 由于AVPacket是创建在栈内，所以函数调用结束后，该对象占用内存会自动释放
    //  ====== 正确的使用方式 二 ====== //
    
    //  ====== 正确的使用方式 三 ====== //
    AVPacket pkt;
    av_init_packet(&initpkt);
    pkt.data = (uint8_t*)av_malloc(300);
    pkt.size = 200;
    // 必须得手动释放内存
    av_freep(pkt.data);
    // 由于AVPacket是创建在栈内，所以函数调用结束后，该对象占用内存会自动释放
    //  ====== 正确的使用方式 三 ====== //
}

+ (void)testAVFrame
{
    /** AVFrame 位于libavutil/frame.h中用于表示未压缩的音视频数据
     *  av_frame_alloc()用于在堆内存中创建一个AVFrame对象，但是uint8_t *data[AV_NUM_DATA_POINTERS];等默认分配为NULL
     *  av_frame_free()释放由av_frame_alloc()分配的对象;内部会调用一次av_frame_unref()函数
     *  av_frame_ref()将引用计数+1
     *  av_frame_unref()将引用计数-1；如果AVFrame引用计数为0，则释放AVFrame分配的uint8_t *data[AV_NUM_DATA_POINTERS]等等内存
     */
    /** AVFrame是否可写：buf不为空，并且对应的flags非AV_BUFFER_FLAG_READONLY
     *  av_frame_make_writable()，首先判断是否可写，不可写则重新创建buf，并将data指向内存拷贝到buf中，将引用计数设置为1
     *  tips：AVFrame对象如果由av_frame_free()等函数释放了，则不能调用此函数了，会奔溃
     */
    //// 创建AVFrame并分配内存的方式 一 ========////
    AVFrame     *p1Frame;
    p1Frame = av_frame_alloc();
    p1Frame->format=AV_PIX_FMT_YUV420P;
    p1Frame->width = 1280;
    p1Frame->height = 720;
    // 为AVFrame分配内存，调用此函数前必须先设置format;width/height(video);nb_samples/channel_layout(audio)
    // 如果AVFrame已经分配了内存，再次调用会造成内存泄漏和不可预知错误；参数二传0即可，表示根据目前cpu类型自动选择对齐的字节数
    av_frame_get_buffer(p1Frame, 0);
    // 让Frame可写
    av_frame_make_writable(p1Frame);
    
    av_frame_unref(p1Frame);
    av_frame_free(&p1Frame);
    //// 创建AVFrame并分配内存的方式 一 ========////
    
    
    //// 创建AVFrame并分配内存的方式 二 ========////
    AVFrame     *p2Frame;
    p2Frame = av_frame_alloc();
    // 先设置值
    p1Frame->format=AV_PIX_FMT_YUV420P;
    p1Frame->width = 1280;
    p1Frame->height = 720;
    // 根据给定的参数分配一块内存空间；注意此时p2Frame的用于引用计数管理的AVBufferRef *buf[AV_NUM_DATA_POINTERS];是NULL，
    // 所以必须通过
    av_image_alloc(p2Frame->data, p2Frame->linesize, p2Frame->width, p2Frame->height, AV_PIX_FMT_YUV420P, 0);
    av_freep(p2Frame->data);
    av_frame_free(&p2Frame);
    //// 创建AVFrame并分配内存的方式 二 ========////
    
    
    
}

@end

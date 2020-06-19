//
//  CodecDefine.h
//  media
//
//  Created by 飞拍科技 on 2019/8/9.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef CodecDefine_h
#define CodecDefine_h

typedef enum
{
    MZCodecTypeEncoder,
    MZCodecTypeDecoder
}MZCodecType;

typedef enum
{
    MZCodecIDTypeH264,
    MZCodecIDTypeAAC,
    MZCodecIDTypeMP3
}MZCodecIDType;

typedef enum
{
    MZPixelFormatYUV420P,
    MZPixelFormatNV12,
    MZPixelFormatNV21,
}MZPixelFormat;

typedef enum
{
    MZSampleFormatFloat,
    MZSampleFormatS32,
    MZSampleFormatFloatP,
    MZSampleFormatS32P,
}MZSampleFormat;

typedef enum
{
    MZChannellayoutMono,
    MZChannellayoutStero,
}MZChannellayout;

#endif /* CodecDefine_h */

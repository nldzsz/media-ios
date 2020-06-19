//
//  Base.hpp
//  media
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef Base_hpp
#define Base_hpp
extern "C"
{
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
}

#include <stdio.h>
using namespace std;

class Base
{
public:
protected:
    // 编解码上下文
    AVCodecContext  *pCodecCtx;
    // 编解码器
    AVCodec         *pCodec;
};

#endif /* Base_hpp */

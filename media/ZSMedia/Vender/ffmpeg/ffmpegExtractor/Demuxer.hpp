//
//  FormatBase.hpp
//  media
//
//  Created by apple on 2019/9/2.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef FormatBase_hpp
#define FormatBase_hpp
extern "C"
{
#include "CLog.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/opt.h"
}

#include <stdio.h>
#include <string>
using namespace std;

class Demuxer
{
protected:
    Demuxer(string filename);
    virtual ~ Demuxer();
protected:
    // 格式上下文
    AVFormatContext *fFormatCtx;
private:
    void initFormatContext(string filename);
};
#endif /* FormatBase_hpp */

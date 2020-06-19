//
//  FormatBase.cpp
//  media
//
//  Created by apple on 2019/9/2.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#include "Demuxer.hpp"

Demuxer::Demuxer(string filename)
{
    if (filename.length() == 0) {
        LOGD("filename is null");
        return;
    }
    
    initFormatContext(filename);
}

Demuxer::~Demuxer()
{
    
}

void Demuxer::initFormatContext(string filename)
{
    
}

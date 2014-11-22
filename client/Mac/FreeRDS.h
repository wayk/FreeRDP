//
//  FreeRDS.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-10-19.
//
//

#ifndef FreeRDS_h
#define FreeRDS_h

struct _RDS_FRAMEBUFFER
{
    int fbWidth;
    int fbHeight;
    int fbAttached;
    int fbScanline;
    int fbSegmentId;
    int fbBitsPerPixel;
    int fbBytesPerPixel;
    BYTE* fbSharedMemory;
    void* image;
};
typedef struct _RDS_FRAMEBUFFER RDS_FRAMEBUFFER;

#endif

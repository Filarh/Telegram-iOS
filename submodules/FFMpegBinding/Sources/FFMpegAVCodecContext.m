#import <FFMpegBinding/FFMpegAVCodecContext.h>

#import <FFMpegBinding/FFMpegAVFrame.h>
#import <FFMpegBinding/FFMpegAVCodec.h>

#import "libavformat/avformat.h"
#import "libavcodec/avcodec.h"

// get_format must return one of the offered formats: if VideoToolbox init fails,
// libavcodec calls it again without AV_PIX_FMT_VIDEOTOOLBOX (avcodec.h, get_format).
static enum AVPixelFormat getPreferredPixelFormat(AVCodecContext *ctx, const enum AVPixelFormat *pix_fmts) {
    for (const enum AVPixelFormat *p = pix_fmts; *p != AV_PIX_FMT_NONE; p++) {
        if (*p == AV_PIX_FMT_VIDEOTOOLBOX) {
            return *p;
        }
    }
    return ctx->sw_pix_fmt;
}

@interface FFMpegAVCodecContext () {
    FFMpegAVCodec *_codec;
    AVCodecContext *_impl;
}

@end

@implementation FFMpegAVCodecContext

- (instancetype)initWithCodec:(FFMpegAVCodec *)codec {
    self = [super init];
    if (self != nil) {
        _codec = codec;
        _impl = avcodec_alloc_context3((AVCodec *)[codec impl]);
        _impl->max_pixels = 4 * 1024 * 4 * 1024;
    }
    return self;
}

- (void)dealloc {
    if (_impl) {
        avcodec_free_context(&_impl);
    }
}

- (void *)impl {
    return _impl;
}

- (int32_t)channels {
    #if LIBAVFORMAT_VERSION_MAJOR >= 59
    return (int32_t)_impl->ch_layout.nb_channels;
    #else
    return (int32_t)_impl->channels;
    #endif
}

- (int32_t)sampleRate {
    return (int32_t)_impl->sample_rate;
}

- (FFMpegAVSampleFormat)sampleFormat {
    return (FFMpegAVSampleFormat)_impl->sample_fmt;
}

- (bool)open {
    int result = avcodec_open2(_impl, (AVCodec *)[_codec impl], nil);
    return result >= 0;
}

- (bool)sendEnd {
    int status = avcodec_send_packet(_impl, nil);
    return status == 0;
}

- (void)setupHardwareAccelerationIfPossible {
    av_hwdevice_ctx_create(&_impl->hw_device_ctx, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, nil, nil, 0);
    _impl->get_format = getPreferredPixelFormat;
}

- (void)setSkipLoopFilterToAll {
    _impl->skip_loop_filter = AVDISCARD_ALL;
}

- (FFMpegAVCodecContextReceiveResult)receiveIntoFrame:(FFMpegAVFrame *)frame {
    int status = avcodec_receive_frame(_impl, (AVFrame *)[frame impl]);
    if (status == 0) {
        return FFMpegAVCodecContextReceiveResultSuccess;
    } else if (status == -35) {
        return FFMpegAVCodecContextReceiveResultNotEnoughData;
    } else {
        return FFMpegAVCodecContextReceiveResultError;
    }
}

- (void)flushBuffers {
    avcodec_flush_buffers(_impl);
}

@end

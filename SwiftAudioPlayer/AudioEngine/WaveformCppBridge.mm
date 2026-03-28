#import "WaveformCppBridge.h"
#import "waveform_peaks.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <vector>
#include <algorithm>

// C++ implementation inline — avoids duplicate symbol from a separate .cpp file
// that Xcode's file-system sync group would compile independently.
extern "C" int generate_waveform_peaks(
    const float *pcm_buffer,
    uint64_t frame_count,
    double sample_rate,
    uint32_t bar_count,
    float *peaks_out,
    uint32_t *peaks_count_out)
{
    if (!pcm_buffer || frame_count == 0 || bar_count == 0 || !peaks_out || !peaks_count_out)
        return 0;

    const uint64_t chunk_frames = frame_count / bar_count;
    if (chunk_frames == 0)
        return 0;

    float global_max_rms = 0.0f;
    std::vector<float> rms_values(bar_count, 0.0f);

    for (uint32_t i = 0; i < bar_count; ++i) {
        const uint64_t start = static_cast<uint64_t>(i) * chunk_frames;
        const uint64_t end   = std::min(start + chunk_frames, frame_count);
        const uint64_t len   = end - start;
        const float *chunk   = pcm_buffer + start;

        double sum_sq = 0.0;
        for (uint64_t j = 0; j < len; ++j) {
            const double s = static_cast<double>(chunk[j]);
            sum_sq += s * s;
        }
        const float rms = static_cast<float>(std::sqrt(sum_sq / static_cast<double>(len)));
        rms_values[i] = rms;
        if (rms > global_max_rms) global_max_rms = rms;
    }

    *peaks_count_out = bar_count;
    if (global_max_rms > 0.0f) {
        for (uint32_t i = 0; i < bar_count; ++i)
            peaks_out[i] = rms_values[i] / global_max_rms;
    } else {
        for (uint32_t i = 0; i < bar_count; ++i)
            peaks_out[i] = 0.0f;
    }

    printf("WaveformPeaks: %llu frames -> %u bars, max_rms=%.4f\n",
           (unsigned long long)frame_count, (unsigned)bar_count, global_max_rms);
    return 1;
}

@implementation WaveformCppBridge

+ (nullable NSArray<NSNumber *> *)generatePeaksFromBuffer:(const float *)pcmBuffer
                                               frameCount:(uint64_t)frameCount
                                               sampleRate:(double)sampleRate
                                                 barCount:(uint32_t)barCount
                                                    error:(NSError **)error {
    if (!pcmBuffer || frameCount == 0 || barCount == 0) {
        if (error)
            *error = [NSError errorWithDomain:@"AudioEngine" code:100
                          userInfo:@{NSLocalizedDescriptionKey: @"Invalid arguments"}];
        return nil;
    }

    std::vector<float> peaks(barCount, 0.0f);
    uint32_t peaksCount = barCount;

    int ok = generate_waveform_peaks(pcmBuffer, frameCount, sampleRate, barCount,
                                     peaks.data(), &peaksCount);
    if (!ok) {
        if (error)
            *error = [NSError errorWithDomain:@"AudioEngine" code:101
                          userInfo:@{NSLocalizedDescriptionKey: @"generate_waveform_peaks failed"}];
        return nil;
    }

    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:peaksCount];
    for (uint32_t i = 0; i < peaksCount; ++i)
        [result addObject:@(peaks[i])];
    return [result copy];
}

@end

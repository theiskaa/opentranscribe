// A flat C surface over whisper.cpp for dart:ffi: the binding never sees
// whisper's struct layouts, and the same file compiles into an Android build later.
#ifndef OTR_WHISPER_H
#define OTR_WHISPER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define OTR_API __attribute__((visibility("default")))

#define OTR_OK 0
#define OTR_ABORTED 1
#define OTR_BAD_ARGS -1
#define OTR_FAILED -2
#define OTR_OUT_OF_RANGE -3

typedef struct otr_whisper otr_whisper;

OTR_API const char *otr_whisper_version(void);

// Loads a ggml model. NULL when the file cannot be loaded. use_gpu is
// honored on a device and ignored in the simulator.
OTR_API otr_whisper *otr_whisper_open(const char *model_path, int32_t use_gpu);

OTR_API void otr_whisper_close(otr_whisper *w);

// Transcribes 16 kHz mono float samples. language is a whisper code ("en",
// "tr"), NULL or empty for auto detection; a code unknown to whisper, or one
// this model has no token for, is OTR_BAD_ARGS.
// abort_flag is polled between passes: nonzero ends the run as OTR_ABORTED.
// progress_out, when given, receives the run's percent (0..100) as whisper
// reports it, so a caller on another thread can poll it mid-run.
// Segments from the previous run are gone once this returns.
OTR_API int32_t otr_whisper_run(
    otr_whisper *w,
    const float *samples,
    int32_t count,
    const char *language,
    int32_t n_threads,
    const int32_t *abort_flag,
    int32_t *progress_out);

OTR_API int32_t otr_whisper_n_segments(otr_whisper *w);

// Reads one segment of the last run: text (owned by the context, valid until
// the next run or close), bounds in centiseconds, and the mean probability of
// its text tokens as confidence (0 when it has none).
OTR_API int32_t otr_whisper_segment(
    otr_whisper *w,
    int32_t index,
    const char **text,
    int64_t *t0_cs,
    int64_t *t1_cs,
    float *confidence);

// Scores how likely 16 kHz mono samples are spoken in each of n_codes whisper
// language codes, renormalized over them into odds_out (summing to 1, or all
// 0 when none is known). A code unknown to whisper or without a token in this
// model scores 0. Only the first 30 s of the samples count. Transcribes
// nothing; runs one encoder pass, which cannot be aborted.
OTR_API int32_t otr_whisper_detect(
    otr_whisper *w,
    const float *samples,
    int32_t count,
    int32_t n_threads,
    const char *const *codes,
    int32_t n_codes,
    float *odds_out);

#ifdef __cplusplus
}
#endif

#endif

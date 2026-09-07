#include "otr_whisper.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <whisper/whisper.h>

#if __has_include(<TargetConditionals.h>)
#include <TargetConditionals.h>
#endif
// The simulator's Metal driver cannot hand a model's buffers to the GPU and
// traps the process; only a device runs on the GPU.
#if defined(TARGET_OS_SIMULATOR) && TARGET_OS_SIMULATOR
#define OTR_GPU_ALLOWED 0
#else
#define OTR_GPU_ALLOWED 1
#endif

// Kept even when nothing native references them: Dart resolves these by
// name from the process image after dead-code stripping.
#define OTR_KEEP __attribute__((used))

struct otr_whisper {
  struct whisper_context *ctx;
};

// Only errors reach the console: a model that fails to load or a backend that
// fails to encode must leave a trace, and everything else is noise.
static void otr_log(enum ggml_log_level level, const char *text, void *user_data) {
  (void)user_data;
  if (level == GGML_LOG_LEVEL_ERROR && text != NULL) fputs(text, stderr);
}

static bool otr_abort(void *user_data) {
  const volatile int32_t *flag = (const volatile int32_t *)user_data;
  return flag != NULL && *flag != 0;
}

static void otr_progress(
    struct whisper_context *ctx, struct whisper_state *state, int progress, void *user_data) {
  (void)ctx;
  (void)state;
  volatile int32_t *out = (volatile int32_t *)user_data;
  if (out != NULL) *out = (int32_t)progress;
}

OTR_KEEP const char *otr_whisper_version(void) { return whisper_version(); }

OTR_KEEP otr_whisper *otr_whisper_open(const char *model_path, int32_t use_gpu) {
  if (model_path == NULL || model_path[0] == '\0') return NULL;
  whisper_log_set(otr_log, NULL);
  struct whisper_context_params cparams = whisper_context_default_params();
  const bool gpu = use_gpu != 0 && OTR_GPU_ALLOWED;
  cparams.use_gpu = gpu;
  cparams.flash_attn = gpu;
  struct whisper_context *ctx = whisper_init_from_file_with_params(model_path, cparams);
  if (ctx == NULL) return NULL;
  otr_whisper *w = calloc(1, sizeof(otr_whisper));
  if (w == NULL) {
    whisper_free(ctx);
    return NULL;
  }
  w->ctx = ctx;
  return w;
}

OTR_KEEP void otr_whisper_close(otr_whisper *w) {
  if (w == NULL) return;
  whisper_free(w->ctx);
  free(w);
}

OTR_KEEP int32_t otr_whisper_run(
    otr_whisper *w,
    const float *samples,
    int32_t count,
    const char *language,
    int32_t n_threads,
    const int32_t *abort_flag,
    int32_t *progress_out) {
  if (w == NULL || samples == NULL || count <= 0 || n_threads <= 0) return OTR_BAD_ARGS;
  if (progress_out != NULL) *progress_out = 0;
  const char *lang = (language == NULL || language[0] == '\0') ? "auto" : language;
  if (strcmp(lang, "auto") != 0) {
    const int lang_id = whisper_lang_id(lang);
    // whisper maps a language to sot + 1 + id with no bounds check, so a
    // language past this model's own token count would silently become the
    // task token instead (Cantonese on a pre-v3 model).
    const int n_langs = whisper_model_n_vocab(w->ctx) - 51765 - whisper_is_multilingual(w->ctx);
    if (lang_id < 0 || lang_id >= n_langs) return OTR_BAD_ARGS;
  }
  if (otr_abort((void *)abort_flag)) return OTR_ABORTED;

  struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.language = lang;
  params.translate = false;
  params.n_threads = n_threads;
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  params.print_special = false;
  params.no_timestamps = false;
  params.single_segment = false;
  params.suppress_nst = true;
  params.abort_callback = otr_abort;
  params.abort_callback_user_data = (void *)abort_flag;
  params.progress_callback = progress_out == NULL ? NULL : otr_progress;
  params.progress_callback_user_data = progress_out;

  int rc = whisper_full(w->ctx, params, samples, count);
  if (rc != 0) return otr_abort((void *)abort_flag) ? OTR_ABORTED : OTR_FAILED;
  return OTR_OK;
}

OTR_KEEP int32_t otr_whisper_n_segments(otr_whisper *w) {
  if (w == NULL) return 0;
  return whisper_full_n_segments(w->ctx);
}

OTR_KEEP int32_t otr_whisper_segment(
    otr_whisper *w,
    int32_t index,
    const char **text,
    int64_t *t0_cs,
    int64_t *t1_cs,
    float *confidence) {
  if (w == NULL || text == NULL || t0_cs == NULL || t1_cs == NULL || confidence == NULL) {
    return OTR_BAD_ARGS;
  }
  if (index < 0 || index >= whisper_full_n_segments(w->ctx)) return OTR_OUT_OF_RANGE;
  *text = whisper_full_get_segment_text(w->ctx, index);
  *t0_cs = whisper_full_get_segment_t0(w->ctx, index);
  *t1_cs = whisper_full_get_segment_t1(w->ctx, index);

  const int n_tokens = whisper_full_n_tokens(w->ctx, index);
  const whisper_token eot = whisper_token_eot(w->ctx);
  double sum = 0;
  int counted = 0;
  for (int i = 0; i < n_tokens; i++) {
    const whisper_token_data token = whisper_full_get_token_data(w->ctx, index, i);
    if (token.id >= eot) continue;
    sum += token.p;
    counted++;
  }
  *confidence = counted == 0 ? 0.0f : (float)(sum / counted);
  return OTR_OK;
}

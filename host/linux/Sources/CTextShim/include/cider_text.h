/*
 * cider_text -- a flat C surface over FreeType and fontconfig.
 *
 * The Linux backend needs three things from the host's text stack: resolve a
 * generic family to a font file, report metrics and advances, and rasterize one
 * glyph to a coverage mask. Everything else about text -- alignment, colour,
 * compositing -- is done in shared Swift so that every backend produces the same
 * pixels.
 *
 * Cider never ships fonts. Faces come from the host's fontconfig database; see
 * docs/07-legal-distribution-boundaries.md.
 */

#ifndef CIDER_TEXT_H
#define CIDER_TEXT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct cider_text_engine cider_text_engine;

/* Weights the shim understands; they map onto fontconfig weight constants. */
enum cider_text_weight {
    CIDER_TEXT_WEIGHT_REGULAR = 0,
    CIDER_TEXT_WEIGHT_BOLD = 1
};

typedef struct {
    /* All values in 26.6-derived whole pixels, positive downward except
       `ascent`, which is positive upward from the baseline. */
    double ascent;
    double descent;
    double line_height;
} cider_text_metrics;

typedef struct {
    uint32_t glyph_id;
    /* Pen advance to the *start* of this glyph, in pixels. */
    double x_offset;
} cider_text_glyph;

typedef struct {
    int width;
    int height;
    int bearing_x;
    int bearing_y;
    /* `width * height` coverage bytes, row-major. Owned by the engine and valid
       until the next call to cider_text_render_glyph on the same engine. */
    const uint8_t *coverage;
} cider_text_bitmap;

/*
 * Creates an engine. `error` receives a human-readable reason on failure.
 * Returns NULL when FreeType or fontconfig could not be initialised.
 */
cider_text_engine *cider_text_engine_create(char *error, size_t error_capacity);

void cider_text_engine_destroy(cider_text_engine *engine);

/*
 * Selects the face used by subsequent calls.
 *
 * `family` is a generic family name such as "sans-serif". `pixel_size` is the
 * size in *device pixels*, already scaled. Returns 0 on success, non-zero when
 * no face could be resolved, writing the reason into `error`.
 */
int cider_text_select_face(cider_text_engine *engine,
                           const char *family,
                           double pixel_size,
                           int weight,
                           char *error,
                           size_t error_capacity);

/* Metrics of the currently selected face. Returns 0 on success. */
int cider_text_face_metrics(cider_text_engine *engine, cider_text_metrics *out);

/*
 * Lays out UTF-32 code points on one line with kerning, writing at most
 * `capacity` glyphs into `glyphs`.
 *
 * Returns the number of glyphs written, or -1 on failure. `*out_width` receives
 * the total advance in pixels even when the glyph array was too small, so a
 * caller can measure without allocating.
 */
int cider_text_shape(cider_text_engine *engine,
                     const uint32_t *code_points,
                     int count,
                     cider_text_glyph *glyphs,
                     int capacity,
                     double *out_width);

/*
 * Rasterizes one glyph to an 8-bit coverage mask. Returns 0 on success, 1 when
 * the glyph has no outline (a space, say), and -1 on failure.
 */
int cider_text_render_glyph(cider_text_engine *engine,
                            uint32_t glyph_id,
                            cider_text_bitmap *out);

/*
 * Reports whether a usable font stack is present, for `cider doctor`. Returns 1
 * when a face could be resolved, 0 otherwise, with a reason in `error`.
 */
int cider_text_probe(char *error, size_t error_capacity);

#ifdef __cplusplus
}
#endif

#endif /* CIDER_TEXT_H */

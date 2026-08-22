#include "cider_text.h"

#include <ft2build.h>
#include <freetype/freetype.h>
#include <fontconfig/fontconfig.h>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Cached faces are keyed by (path, pixel size, weight). A demo screen touches
   two or three faces, so a small fixed cache is enough and keeps the shim free
   of a hash-table implementation. */
#define CIDER_TEXT_FACE_CACHE 8

struct cached_face {
    char path[512];
    int face_index;
    double pixel_size;
    FT_Face face;
};

struct cider_text_engine {
    FT_Library library;
    struct cached_face cache[CIDER_TEXT_FACE_CACHE];
    int cache_count;
    FT_Face current;

    /* Coverage buffer handed back by cider_text_render_glyph. Grown as needed
       and owned here so callers never free anything. */
    uint8_t *coverage;
    size_t coverage_capacity;
};

static void set_error(char *error, size_t capacity, const char *message) {
    if (error == NULL || capacity == 0) {
        return;
    }
    strncpy(error, message, capacity - 1);
    error[capacity - 1] = '\0';
}

/* Fixed-point 26.6 to pixels. */
static double f26_6(FT_Pos value) {
    return (double)value / 64.0;
}

/*
 * Asks fontconfig for a file matching `family` and `weight`.
 * Returns 0 on success and fills `path` / `face_index`.
 */
static int resolve_font_file(const char *family,
                             int weight,
                             char *path,
                             size_t path_capacity,
                             int *face_index,
                             char *error,
                             size_t error_capacity) {
    if (!FcInit()) {
        set_error(error, error_capacity, "fontconfig could not be initialised");
        return 1;
    }

    FcPattern *pattern = FcPatternCreate();
    if (pattern == NULL) {
        set_error(error, error_capacity, "out of memory building a font pattern");
        return 1;
    }

    FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *)(family != NULL ? family : "sans-serif"));
    FcPatternAddInteger(pattern, FC_WEIGHT,
                        weight == CIDER_TEXT_WEIGHT_BOLD ? FC_WEIGHT_BOLD : FC_WEIGHT_REGULAR);
    FcPatternAddBool(pattern, FC_SCALABLE, FcTrue);

    FcConfigSubstitute(NULL, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);

    FcResult result = FcResultNoMatch;
    FcPattern *matched = FcFontMatch(NULL, pattern, &result);
    FcPatternDestroy(pattern);

    if (matched == NULL || result != FcResultMatch) {
        if (matched != NULL) {
            FcPatternDestroy(matched);
        }
        set_error(error, error_capacity, "fontconfig found no scalable font on this host");
        return 1;
    }

    FcChar8 *file = NULL;
    if (FcPatternGetString(matched, FC_FILE, 0, &file) != FcResultMatch || file == NULL) {
        FcPatternDestroy(matched);
        set_error(error, error_capacity, "the matched font has no file on disk");
        return 1;
    }

    int index = 0;
    FcPatternGetInteger(matched, FC_INDEX, 0, &index);

    strncpy(path, (const char *)file, path_capacity - 1);
    path[path_capacity - 1] = '\0';
    *face_index = index;

    FcPatternDestroy(matched);
    return 0;
}

cider_text_engine *cider_text_engine_create(char *error, size_t error_capacity) {
    struct cider_text_engine *engine = calloc(1, sizeof(struct cider_text_engine));
    if (engine == NULL) {
        set_error(error, error_capacity, "out of memory");
        return NULL;
    }

    FT_Error status = FT_Init_FreeType(&engine->library);
    if (status != 0) {
        set_error(error, error_capacity, "FreeType could not be initialised");
        free(engine);
        return NULL;
    }

    return engine;
}

void cider_text_engine_destroy(cider_text_engine *engine) {
    if (engine == NULL) {
        return;
    }
    for (int i = 0; i < engine->cache_count; ++i) {
        if (engine->cache[i].face != NULL) {
            FT_Done_Face(engine->cache[i].face);
        }
    }
    if (engine->library != NULL) {
        FT_Done_FreeType(engine->library);
    }
    free(engine->coverage);
    free(engine);
}

int cider_text_select_face(cider_text_engine *engine,
                           const char *family,
                           double pixel_size,
                           int weight,
                           char *error,
                           size_t error_capacity) {
    if (engine == NULL || pixel_size <= 0) {
        set_error(error, error_capacity, "invalid font request");
        return 1;
    }

    char path[512];
    int face_index = 0;
    if (resolve_font_file(family, weight, path, sizeof(path), &face_index,
                          error, error_capacity) != 0) {
        return 1;
    }

    for (int i = 0; i < engine->cache_count; ++i) {
        struct cached_face *entry = &engine->cache[i];
        if (entry->face_index == face_index &&
            entry->pixel_size == pixel_size &&
            strcmp(entry->path, path) == 0) {
            engine->current = entry->face;
            return 0;
        }
    }

    FT_Face face = NULL;
    if (FT_New_Face(engine->library, path, face_index, &face) != 0) {
        char message[640];
        snprintf(message, sizeof(message), "FreeType could not open the font file %s", path);
        set_error(error, error_capacity, message);
        return 1;
    }

    /* Round to whole pixels: fractional ppem makes advances drift between runs,
       which would make visual baselines flaky. */
    FT_UInt ppem = (FT_UInt)(pixel_size + 0.5);
    if (ppem == 0) {
        ppem = 1;
    }
    if (FT_Set_Pixel_Sizes(face, 0, ppem) != 0) {
        FT_Done_Face(face);
        set_error(error, error_capacity, "the font does not support the requested pixel size");
        return 1;
    }

    if (engine->cache_count == CIDER_TEXT_FACE_CACHE) {
        /* Evict the oldest entry. A demo screen never reaches this, and an
           application that does will simply pay a reopen. */
        FT_Done_Face(engine->cache[0].face);
        memmove(&engine->cache[0], &engine->cache[1],
                sizeof(struct cached_face) * (CIDER_TEXT_FACE_CACHE - 1));
        engine->cache_count -= 1;
    }

    struct cached_face *entry = &engine->cache[engine->cache_count++];
    strncpy(entry->path, path, sizeof(entry->path) - 1);
    entry->path[sizeof(entry->path) - 1] = '\0';
    entry->face_index = face_index;
    entry->pixel_size = pixel_size;
    entry->face = face;

    engine->current = face;
    return 0;
}

int cider_text_face_metrics(cider_text_engine *engine, cider_text_metrics *out) {
    if (engine == NULL || engine->current == NULL || out == NULL) {
        return 1;
    }
    FT_Size_Metrics metrics = engine->current->size->metrics;
    out->ascent = f26_6(metrics.ascender);
    out->descent = -f26_6(metrics.descender);
    out->line_height = f26_6(metrics.height);
    return 0;
}

int cider_text_shape(cider_text_engine *engine,
                     const uint32_t *code_points,
                     int count,
                     cider_text_glyph *glyphs,
                     int capacity,
                     double *out_width) {
    if (engine == NULL || engine->current == NULL || count < 0) {
        return -1;
    }
    if (count > 0 && code_points == NULL) {
        return -1;
    }

    FT_Face face = engine->current;
    const FT_Bool has_kerning = FT_HAS_KERNING(face);

    double pen = 0.0;
    int written = 0;
    FT_UInt previous = 0;

    for (int i = 0; i < count; ++i) {
        FT_UInt glyph_index = FT_Get_Char_Index(face, (FT_ULong)code_points[i]);

        if (has_kerning && previous != 0 && glyph_index != 0) {
            FT_Vector delta;
            if (FT_Get_Kerning(face, previous, glyph_index, FT_KERNING_DEFAULT, &delta) == 0) {
                pen += f26_6(delta.x);
            }
        }

        if (glyphs != NULL && written < capacity) {
            glyphs[written].glyph_id = (uint32_t)glyph_index;
            glyphs[written].x_offset = pen;
            written += 1;
        }

        if (FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT) == 0) {
            pen += f26_6(face->glyph->advance.x);
        }
        previous = glyph_index;
    }

    if (out_width != NULL) {
        *out_width = pen;
    }
    return written;
}

int cider_text_render_glyph(cider_text_engine *engine,
                            uint32_t glyph_id,
                            cider_text_bitmap *out) {
    if (engine == NULL || engine->current == NULL || out == NULL) {
        return -1;
    }
    memset(out, 0, sizeof(*out));

    FT_Face face = engine->current;
    if (FT_Load_Glyph(face, (FT_UInt)glyph_id, FT_LOAD_RENDER) != 0) {
        return -1;
    }

    FT_GlyphSlot slot = face->glyph;
    FT_Bitmap *bitmap = &slot->bitmap;
    if (bitmap->width == 0 || bitmap->rows == 0) {
        return 1;
    }
    if (bitmap->pixel_mode != FT_PIXEL_MODE_GRAY) {
        /* FT_LOAD_RENDER without FT_LOAD_MONOCHROME always produces 8-bit gray;
           anything else means the face did something unexpected. Refuse rather
           than misinterpret the buffer. */
        return -1;
    }

    size_t needed = (size_t)bitmap->width * (size_t)bitmap->rows;
    if (engine->coverage_capacity < needed) {
        uint8_t *grown = realloc(engine->coverage, needed);
        if (grown == NULL) {
            return -1;
        }
        engine->coverage = grown;
        engine->coverage_capacity = needed;
    }

    /* FreeType rows are `pitch` bytes apart, which is not the same as `width`,
       and pitch is negative for bottom-up bitmaps. Copy row by row into a tight
       buffer so the Swift side never has to know that. */
    for (unsigned int row = 0; row < bitmap->rows; ++row) {
        const unsigned char *source = bitmap->pitch >= 0
            ? bitmap->buffer + (size_t)row * (size_t)bitmap->pitch
            : bitmap->buffer + (size_t)(bitmap->rows - 1 - row) * (size_t)(-bitmap->pitch);
        memcpy(engine->coverage + (size_t)row * (size_t)bitmap->width, source, bitmap->width);
    }

    out->width = (int)bitmap->width;
    out->height = (int)bitmap->rows;
    out->bearing_x = slot->bitmap_left;
    out->bearing_y = slot->bitmap_top;
    out->coverage = engine->coverage;
    return 0;
}

int cider_text_probe(char *error, size_t error_capacity) {
    char path[512];
    int face_index = 0;
    if (resolve_font_file("sans-serif", CIDER_TEXT_WEIGHT_REGULAR, path, sizeof(path),
                          &face_index, error, error_capacity) != 0) {
        return 0;
    }

    FT_Library library = NULL;
    if (FT_Init_FreeType(&library) != 0) {
        set_error(error, error_capacity, "FreeType could not be initialised");
        return 0;
    }

    FT_Face face = NULL;
    if (FT_New_Face(library, path, face_index, &face) != 0) {
        FT_Done_FreeType(library);
        set_error(error, error_capacity, "FreeType could not open the host's default font");
        return 0;
    }

    FT_Done_Face(face);
    FT_Done_FreeType(library);
    return 1;
}

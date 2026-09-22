#ifdef __APPLE__
#include <ncnn/ncnn/benchmark.h>
#include <ncnn/ncnn/layer.h>
#include <ncnn/ncnn/net.h>

#else
#include "benchmark.h"
#include "layer.h"
#include "net.h"
#endif
#include <opencv2/highgui/highgui.hpp>

#include "vision.h"
#include "yolov8_bin.h"
#include "yolov8_param.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <float.h>
#include <mutex>
#include <nlohmann/json.hpp>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>
#ifdef __ANDROID__
#include <cpu.h>
#endif

using json = nlohmann::json;

using namespace std;

static ncnn::UnlockedPoolAllocator g_blob_pool_allocator;
static ncnn::PoolAllocator g_workspace_pool_allocator;

static ncnn::Net yolov11;
static std::mutex detectMutex;
static std::once_flag g_cpu_init_flag;
static int g_cpu_init_result = -1;

static const int DETECT_PASS_SINGLE = 1;
static const int DETECT_PASS_DOUBLE = 2;
static const int YOLO_INPUT_SIZE = 640;

struct Object {
  float x;
  float y;
  float w;
  float h;
  int label;
  float prob;
  int row = -1;
  int col = -1;
};

struct RectFNative {
  float left;
  float top;
  float right;
  float bottom;
};

struct PositionInfo {
  float x;
  float y;
  float w;
  float h;
  string label;
  string san;
  float prob;
};

static const int BOARD_GRID_SIZE = 8;
static const int BOARD_CELL_SAMPLE_GRID_SIZE = 12;
static const int BOARD_CELL_SAMPLE_COUNT =
    BOARD_CELL_SAMPLE_GRID_SIZE * BOARD_CELL_SAMPLE_GRID_SIZE;
static const int BOARD_GRAY_SAMPLE_COUNT =
    BOARD_GRID_SIZE * BOARD_GRID_SIZE * BOARD_CELL_SAMPLE_COUNT;
static const long long FORCE_DETECT_INTERVAL_MS = 5000;
static const double CACHE_AVG_DIFF_THRESHOLD = 4.0;
static const double CACHE_MAX_CELL_DIFF_THRESHOLD = 10.0;
static const int CACHE_SAMPLE_GRAY_DIFF_THRESHOLD = 8;
static const double CACHE_MIN_CELL_GRAY_SIMILARITY = 0.90;

static std::mutex g_cache_mutex;
static bool g_cache_valid = false;
static int g_cached_pass_count = DETECT_PASS_DOUBLE;
static std::vector<Object> g_cached_objects;
static RectFNative g_cached_board_rect;
static double g_cached_board_feature[BOARD_GRID_SIZE * BOARD_GRID_SIZE];
static uint8_t g_cached_board_gray_samples[BOARD_GRAY_SAMPLE_COUNT];
static int g_cached_bitmap_width = 0;
static int g_cached_bitmap_height = 0;
static long long g_last_real_detect_time_ms = 0;
static std::string g_last_cache_status = "no cache";

static long long now_ms() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}

static float clamp_float(float value, float min_value, float max_value) {
  return std::max(min_value, std::min(max_value, value));
}

static bool is_valid_board(const std::vector<Object> &objects) {
  return objects.size() >= 64;
}

static bool build_board_rect(const std::vector<Object> &objects,
                             int image_width, int image_height,
                             RectFNative &rect) {
  if (!is_valid_board(objects))
    return false;

  float left = FLT_MAX;
  float top = FLT_MAX;
  float right = 0.f;
  float bottom = 0.f;

  for (size_t i = 0; i < objects.size(); i++) {
    left = std::min(left, objects[i].x);
    top = std::min(top, objects[i].y);
    right = std::max(right, objects[i].x + objects[i].w);
    bottom = std::max(bottom, objects[i].y + objects[i].h);
  }

  float width = right - left;
  float height = bottom - top;
  if (width < 20.f || height < 20.f)
    return false;

  float pad_x = width * 0.05f;
  float pad_y = height * 0.05f;
  rect.left = clamp_float(left - pad_x, 0.f, (float)image_width - 1.f);
  rect.top = clamp_float(top - pad_y, 0.f, (float)image_height - 1.f);
  rect.right = clamp_float(right + pad_x, 1.f, (float)image_width);
  rect.bottom = clamp_float(bottom + pad_y, 1.f, (float)image_height);

  return rect.right > rect.left && rect.bottom > rect.top;
}

static bool compute_board_feature(const unsigned char *pixels, int image_width,
                                  int image_height, int stride,
                                  const RectFNative &rect,
                                  double feature[BOARD_GRID_SIZE *
                                                 BOARD_GRID_SIZE]) {
  if (rect.right - rect.left < BOARD_GRID_SIZE ||
      rect.bottom - rect.top < BOARD_GRID_SIZE)
    return false;

  float cell_width = (rect.right - rect.left) / BOARD_GRID_SIZE;
  float cell_height = (rect.bottom - rect.top) / BOARD_GRID_SIZE;

  for (int row = 0; row < BOARD_GRID_SIZE; row++) {
    for (int col = 0; col < BOARD_GRID_SIZE; col++) {
      int left = std::max(0, (int)roundf(rect.left + col * cell_width));
      int top = std::max(0, (int)roundf(rect.top + row * cell_height));
      int right =
          std::min(image_width, (int)roundf(rect.left + (col + 1) * cell_width));
      int bottom = std::min(
          image_height, (int)roundf(rect.top + (row + 1) * cell_height));
      int step_x = std::max(1, (right - left) / 12);
      int step_y = std::max(1, (bottom - top) / 12);
      long long gray_sum = 0;
      int count = 0;

      for (int y = top; y < bottom; y += step_y) {
        const unsigned char *row_pixels = pixels + y * stride;
        for (int x = left; x < right; x += step_x) {
          const unsigned char *pixel = row_pixels + x * 3;
          int blue = pixel[0];
          int green = pixel[1];
          int red = pixel[2];
          gray_sum += (red * 30 + green * 59 + blue * 11) / 100;
          count++;
        }
      }

      if (count == 0)
        return false;

      feature[row * BOARD_GRID_SIZE + col] = (double)gray_sum / count;
    }
  }

  return true;
}

static bool compute_board_gray_samples(
    const unsigned char *pixels, int image_width, int image_height, int stride,
    const RectFNative &rect, uint8_t samples[BOARD_GRAY_SAMPLE_COUNT]) {
  if (rect.right - rect.left < BOARD_GRID_SIZE ||
      rect.bottom - rect.top < BOARD_GRID_SIZE)
    return false;

  float cell_width = (rect.right - rect.left) / BOARD_GRID_SIZE;
  float cell_height = (rect.bottom - rect.top) / BOARD_GRID_SIZE;

  for (int row = 0; row < BOARD_GRID_SIZE; row++) {
    for (int col = 0; col < BOARD_GRID_SIZE; col++) {
      int left = std::max(0, (int)roundf(rect.left + col * cell_width));
      int top = std::max(0, (int)roundf(rect.top + row * cell_height));
      int right =
          std::min(image_width, (int)roundf(rect.left + (col + 1) * cell_width));
      int bottom = std::min(
          image_height, (int)roundf(rect.top + (row + 1) * cell_height));
      if (right <= left || bottom <= top)
        return false;

      int cell_index = row * BOARD_GRID_SIZE + col;
      int cell_offset = cell_index * BOARD_CELL_SAMPLE_COUNT;
      for (int sample_row = 0; sample_row < BOARD_CELL_SAMPLE_GRID_SIZE;
           sample_row++) {
        int y = top + ((sample_row * 2 + 1) * (bottom - top)) /
                          (BOARD_CELL_SAMPLE_GRID_SIZE * 2);
        y = std::min(bottom - 1, std::max(top, y));
        const unsigned char *row_pixels = pixels + y * stride;

        for (int sample_col = 0; sample_col < BOARD_CELL_SAMPLE_GRID_SIZE;
             sample_col++) {
          int x = left + ((sample_col * 2 + 1) * (right - left)) /
                             (BOARD_CELL_SAMPLE_GRID_SIZE * 2);
          x = std::min(right - 1, std::max(left, x));
          const unsigned char *pixel = row_pixels + x * 3;
          int blue = pixel[0];
          int green = pixel[1];
          int red = pixel[2];
          int sample_index = sample_row * BOARD_CELL_SAMPLE_GRID_SIZE +
                             sample_col;
          samples[cell_offset + sample_index] =
              (uint8_t)((red * 30 + green * 59 + blue * 11) / 100);
        }
      }
    }
  }

  return true;
}

static void clear_native_cache_locked() {
  g_cache_valid = false;
  g_cached_objects.clear();
  g_cached_bitmap_width = 0;
  g_cached_bitmap_height = 0;
  g_last_real_detect_time_ms = 0;
}

static void set_cache_status(const std::string &status) {
  g_last_cache_status = status;
}

// objects to Obj[]
static const char *class_names[] = {
    "Empty",       "wPawn",       "wRook",       "wKnight",   "wBishop",
    "wKing",       "wQueen",      "bPawn",       "bRook",     "bKnight",
    "bBishop",     "bKing",       "bQueue",      "star",      "wPromotion1",
    "wPromotion2", "bPromotion1", "bPromotion2", "wQueen_P",  "bQueen_P",
    "wRook_P",     "bRook_P",     "wBishop_P",   "bBishop_P", "wKnight_P",
    "bKnight_P"};

static const char *promote_name[][4] = {
    {"wQueen_P", "wKnight_P", "wRook_P", "wBishop_P"},
    {"wBishop_P", "wRook_P", "wKnight_P", "wQueen_P"},
    {"bQueen_P", "bKnight_P", "bRook_P", "bBishop_P"},
    {"bBishop_P", "bRook_P", "bKnight_P", "bQueen_P"},
    {"wQueen_P", "wRook_P", "wBishop_P", "wKnight_P"},
    {"bQueen_P", "bRook_P", "bBishop_P", "bKnight_P"}};

static const string san_names[] = {"",  "P", "R", "N", "B", "K", "Q", "p", "r",
                                   "n", "b", "k", "q", "",  "",  "",  "",  "",
                                   "",  "",  "",  "",  "",  "",  "",  ""};

static inline float intersection_area(const Object &a, const Object &b) {
  if (a.x > b.x + b.w || a.x + a.w < b.x || a.y > b.y + b.h ||
      a.y + a.h < b.y) {
    // no intersection
    return 0.f;
  }

  float inter_width = std::min(a.x + a.w, b.x + b.w) - std::max(a.x, b.x);
  float inter_height = std::min(a.y + a.h, b.y + b.h) - std::max(a.y, b.y);

  return inter_width * inter_height;
}

static void qsort_descent_inplace(std::vector<Object> &faceobjects) {
  std::sort(faceobjects.begin(), faceobjects.end(),
            [](const Object &a, const Object &b) { return a.prob > b.prob; });
}

static void nms_sorted_bboxes(const std::vector<Object> &faceobjects,
                              std::vector<int> &picked, float nms_threshold) {
  picked.clear();

  const int n = faceobjects.size();

  std::vector<float> areas(n);
  for (int i = 0; i < n; i++) {
    areas[i] = faceobjects[i].w * faceobjects[i].h;
  }

  for (int i = 0; i < n; i++) {
    const Object &a = faceobjects[i];

    bool keep = true;
    for (int j = 0; j < (int)picked.size(); j++) {
      const Object &b = faceobjects[picked[j]];
      if (a.label != b.label)
        continue;

      float inter_area = intersection_area(a, b);
      float union_area = areas[i] + areas[picked[j]] - inter_area;
      float threshold = nms_threshold;
      if (a.label >= 0 && a.label <= 13)
        threshold = std::max(threshold, 0.70f);
      if (union_area > 0.f && inter_area / union_area > threshold) {
        keep = false;
        break;
      }
    }

    if (keep)
      picked.push_back(i);
  }
}

static std::vector<Object>
suppress_overlapping_any_label(std::vector<Object> objects,
                               float nms_threshold) {
  qsort_descent_inplace(objects);
  std::vector<Object> picked;
  for (const Object &candidate : objects) {
    bool keep = true;
    for (const Object &selected : picked) {
      float intersection = intersection_area(candidate, selected);
      float union_area = candidate.w * candidate.h + selected.w * selected.h -
                         intersection;
      if (union_area > 0.f && intersection / union_area > nms_threshold) {
        keep = false;
        break;
      }
    }
    if (keep)
      picked.push_back(candidate);
  }
  return picked;
}

static std::vector<Object>
keep_square_like_candidates(const std::vector<Object> &objects) {
  if (objects.size() < 64)
    return objects;

  std::vector<float> areas;
  areas.reserve(objects.size());
  for (const Object &object : objects) {
    if (object.w > 1.f && object.h > 1.f)
      areas.push_back(object.w * object.h);
  }
  if (areas.empty())
    return objects;

  std::nth_element(areas.begin(), areas.begin() + areas.size() / 2,
                   areas.end());
  float median_area = areas[areas.size() / 2];
  std::vector<Object> filtered;
  filtered.reserve(objects.size());
  for (const Object &object : objects) {
    float area = object.w * object.h;
    float aspect = std::max(object.w, object.h) /
                   std::max(1.f, std::min(object.w, object.h));
    if (aspect > 1.35f || area < median_area * 0.45f ||
        area > median_area * 1.80f)
      continue;
    filtered.push_back(object);
  }
  return filtered.size() >= 60 ? filtered : objects;
}

static inline float sigmoid(float x) {
  return static_cast<float>(1.f / (1.f + std::exp(-x)));
}

static inline float score_value(float x) {
  return (x < 0.f || x > 1.f) ? sigmoid(x) : x;
}

static inline float class_score_threshold(int label,
                                          float default_threshold) {
  return label == 13 ? std::min(default_threshold, 0.20f)
                     : default_threshold;
}

static void push_decoded_object(std::vector<Object> &proposals, float cx,
                                float cy, float bw, float bh, int in_w,
                                int in_h, int label, float score) {
  if (bw <= 2.f && bh <= 2.f && cx <= 2.f && cy <= 2.f) {
    cx *= in_w;
    bw *= in_w;
    cy *= in_h;
    bh *= in_h;
  }

  Object obj;
  obj.x = cx - bw * 0.5f;
  obj.y = cy - bh * 0.5f;
  obj.w = bw;
  obj.h = bh;
  obj.label = label;
  obj.prob = score;
  proposals.push_back(obj);
}

static float out_at_2d(const ncnn::Mat &out, int channel, int anchor,
                       int channels, int anchors) {
  if (out.h == channels && out.w == anchors)
    return out.row(channel)[anchor];
  return out.row(anchor)[channel];
}

static void decode_yolov11_output(const ncnn::Mat &out, int in_w, int in_h,
                                  float threshold,
                                  std::vector<Object> &proposals) {
  int channels = 0;
  int anchors = 0;
  if (out.dims == 2) {
    if (out.h <= out.w) {
      channels = out.h;
      anchors = out.w;
    } else {
      channels = out.w;
      anchors = out.h;
    }
  } else if (out.dims == 3) {
    ncnn::Mat flat = out.reshape(out.w, out.h * out.c);
    decode_yolov11_output(flat, in_w, in_h, threshold, proposals);
    return;
  } else {
    return;
  }

  if (channels < 10)
    return;
  const int num_class = channels - 4;
  for (int i = 0; i < anchors; i++) {
    int best_class = 0;
    float best_score = -FLT_MAX;
    for (int c = 0; c < num_class; c++) {
      float score = score_value(out_at_2d(out, c + 4, i, channels, anchors));
      if (score > best_score) {
        best_score = score;
        best_class = c;
      }
    }
    if (best_score < class_score_threshold(best_class, threshold))
      continue;

    push_decoded_object(proposals,
                        out_at_2d(out, 0, i, channels, anchors),
                        out_at_2d(out, 1, i, channels, anchors),
                        out_at_2d(out, 2, i, channels, anchors),
                        out_at_2d(out, 3, i, channels, anchors), in_w, in_h,
                        best_class, best_score);
  }
}

static bool input_any(ncnn::Extractor &ex, const ncnn::Mat &in) {
  const char *names[] = {"in0", "images", "input", "data"};
  for (const char *name : names) {
    if (ex.input(name, in) == 0)
      return true;
  }
  return false;
}

static bool extract_any(ncnn::Extractor &ex, ncnn::Mat &out) {
  const char *names[] = {"out0", "output0", "output", "outputs", "386",
                         "Detect_output"};
  for (const char *name : names) {
    if (ex.extract(name, out) == 0 && out.total() > 0)
      return true;
  }
  return false;
}

ncnn::Mat convert_rgb_to_gray3ch(const ncnn::Mat &rgb) {
  if (rgb.c != 3) {
    return rgb.clone();
  }

  int w = rgb.w;
  int h = rgb.h;

  const float *r = rgb.channel(0);
  const float *g = rgb.channel(1);
  const float *b = rgb.channel(2);

  ncnn::Mat gray3c(w, h, 3);
  float *out_r = gray3c.channel(0);
  float *out_g = gray3c.channel(1);
  float *out_b = gray3c.channel(2);

  int size = w * h;
  for (int i = 0; i < size; i++) {
    float gray = 0.299f * r[i] + 0.587f * g[i] + 0.114f * b[i];
    out_r[i] = gray;
    out_g[i] = gray;
    out_b[i] = gray;
  }

  return gray3c;
}

static void resize_antialiased(const ncnn::Mat &src, ncnn::Mat &dst,
                               int dst_w, int dst_h) {
  const float downscale =
      std::max((float)src.w / dst_w, (float)src.h / dst_h);
  if (src.w <= dst_w || src.h <= dst_h || downscale < 3.f) {
    ncnn::resize_bilinear(src, dst, dst_w, dst_h);
    return;
  }

  ncnn::Mat horizontal(dst_w, src.h, src.c);
  for (int q = 0; q < src.c; q++) {
    const ncnn::Mat src_channel = src.channel(q);
    ncnn::Mat horizontal_channel = horizontal.channel(q);
    for (int y = 0; y < src.h; y++) {
      const float *src_row = src_channel.row(y);
      float *horizontal_row = horizontal_channel.row(y);
      for (int x = 0; x < dst_w; x++) {
        int begin = (int)((int64_t)x * src.w / dst_w);
        int end = (int)((int64_t)(x + 1) * src.w / dst_w);
        end = std::max(begin + 1, std::min(end, src.w));
        float sum = 0.f;
        for (int sx = begin; sx < end; sx++)
          sum += src_row[sx];
        horizontal_row[x] = sum / (end - begin);
      }
    }
  }

  dst.create(dst_w, dst_h, src.c);
  for (int q = 0; q < src.c; q++) {
    const ncnn::Mat horizontal_channel = horizontal.channel(q);
    ncnn::Mat dst_channel = dst.channel(q);
    for (int y = 0; y < dst_h; y++) {
      int begin = (int)((int64_t)y * src.h / dst_h);
      int end = (int)((int64_t)(y + 1) * src.h / dst_h);
      end = std::max(begin + 1, std::min(end, src.h));
      float *dst_row = dst_channel.row(y);
      std::fill(dst_row, dst_row + dst_w, 0.f);
      for (int sy = begin; sy < end; sy++) {
        const float *horizontal_row = horizontal_channel.row(sy);
        for (int x = 0; x < dst_w; x++)
          dst_row[x] += horizontal_row[x];
      }
      const float inv_count = 1.f / (end - begin);
      for (int x = 0; x < dst_w; x++)
        dst_row[x] *= inv_count;
    }
  }
}

static void runYoloInference(const ncnn::Mat &rgb_mat, int img_w, int img_h,
                             std::vector<Object> &objects) {
  int w = img_w;
  int h = img_h;
  float scale = 1.f;
  if (w > h) {
    scale = (float)YOLO_INPUT_SIZE / w;
    w = YOLO_INPUT_SIZE;
    h = (int)(h * scale);
  } else {
    scale = (float)YOLO_INPUT_SIZE / h;
    h = YOLO_INPUT_SIZE;
    w = (int)(w * scale);
  }

  ncnn::Mat in;
  resize_antialiased(rgb_mat, in, w, h);

  int wpad = YOLO_INPUT_SIZE - w;
  int hpad = YOLO_INPUT_SIZE - h;
  ncnn::Mat in_pad;
  ncnn::copy_make_border(in, in_pad, hpad / 2, hpad - hpad / 2, wpad / 2,
                         wpad - wpad / 2, ncnn::BORDER_CONSTANT, 114.f);

  const float prob_threshold = 0.25f;
  const float nms_threshold = 0.45f;

  const float norm_vals[3] = {1 / 255.f, 1 / 255.f, 1 / 255.f};
  in_pad.substract_mean_normalize(nullptr, norm_vals);

  std::vector<Object> proposals;
  ncnn::Extractor ex = yolov11.create_extractor();
  ex.set_light_mode(true);
  if (!input_any(ex, in_pad)) {
    objects.clear();
    return;
  }
  ncnn::Mat out;
  if (!extract_any(ex, out)) {
    objects.clear();
    return;
  }
  decode_yolov11_output(out, in_pad.w, in_pad.h, prob_threshold, proposals);

  qsort_descent_inplace(proposals);

  std::vector<int> picked;
  nms_sorted_bboxes(proposals, picked, nms_threshold);

  objects.clear();
  objects.reserve(picked.size());
  for (int index : picked) {
    Object object = proposals[index];

    float x0 = (object.x - (wpad / 2.f)) / scale;
    float y0 = (object.y - (hpad / 2.f)) / scale;
    float x1 = (object.x + object.w - (wpad / 2.f)) / scale;
    float y1 = (object.y + object.h - (hpad / 2.f)) / scale;

    x0 = std::max(std::min(x0, (float)(img_w - 1)), 0.f);
    y0 = std::max(std::min(y0, (float)(img_h - 1)), 0.f);
    x1 = std::max(std::min(x1, (float)(img_w - 1)), 0.f);
    y1 = std::max(std::min(y1, (float)(img_h - 1)), 0.f);

    object.x = x0;
    object.y = y0;
    object.w = x1 - x0;
    object.h = y1 - y0;
    if (object.w > 1.f && object.h > 1.f)
      objects.push_back(object);
  }
}

static inline float object_cx(const Object &object) {
  return object.x + object.w * 0.5f;
}

static inline float object_cy(const Object &object) {
  return object.y + object.h * 0.5f;
}

static inline float object_cell_len(const Object &object) {
  return (object.w + object.h) * 0.5f;
}

static int lattice_find(std::vector<int> &parent, int index) {
  if (parent[index] != index)
    parent[index] = lattice_find(parent, parent[index]);
  return parent[index];
}

static void lattice_union(std::vector<int> &parent, int a, int b) {
  int root_a = lattice_find(parent, a);
  int root_b = lattice_find(parent, b);
  if (root_a != root_b)
    parent[root_a] = root_b;
}

struct LatticePoint {
  int grid_x;
  int grid_y;
  int object_index;
  float residual;
};

struct LatticeFit {
  bool valid = false;
  float score = -FLT_MAX;
  std::vector<Object> cells;
};

static LatticeFit
fit_component_to_board(const std::vector<Object> &candidates,
                       const std::vector<int> &indices) {
  LatticeFit best;
  if (indices.size() < 48)
    return best;

  for (int anchor_index : indices) {
    const Object &anchor = candidates[anchor_index];
    const float cell = object_cell_len(anchor);
    if (cell <= 2.f)
      continue;

    const float anchor_x = object_cx(anchor);
    const float anchor_y = object_cy(anchor);
    std::vector<LatticePoint> points;
    int min_grid_x = 999;
    int min_grid_y = 999;
    int max_grid_x = -999;
    int max_grid_y = -999;

    for (int index : indices) {
      const Object &object = candidates[index];
      const int grid_x =
          (int)std::round((object_cx(object) - anchor_x) / cell);
      const int grid_y =
          (int)std::round((object_cy(object) - anchor_y) / cell);
      const float residual_x =
          std::fabs(object_cx(object) - (anchor_x + grid_x * cell));
      const float residual_y =
          std::fabs(object_cy(object) - (anchor_y + grid_y * cell));
      const float residual = std::max(residual_x, residual_y) / cell;
      const float size_ratio = object_cell_len(object) / cell;
      if (size_ratio < 0.65f || size_ratio > 1.45f || residual > 0.28f)
        continue;

      points.push_back({grid_x, grid_y, index, residual});
      min_grid_x = std::min(min_grid_x, grid_x);
      min_grid_y = std::min(min_grid_y, grid_y);
      max_grid_x = std::max(max_grid_x, grid_x);
      max_grid_y = std::max(max_grid_y, grid_y);
    }

    if (points.size() < 48 || max_grid_x - min_grid_x + 1 < 8 ||
        max_grid_y - min_grid_y + 1 < 8) {
      continue;
    }

    for (int left = min_grid_x; left <= max_grid_x - 7; left++) {
      for (int top = min_grid_y; top <= max_grid_y - 7; top++) {
        int locations[8][8];
        float residuals[8][8];
        for (int row = 0; row < 8; row++) {
          for (int col = 0; col < 8; col++) {
            locations[row][col] = -1;
            residuals[row][col] = FLT_MAX;
          }
        }

        for (const LatticePoint &point : points) {
          const int col = point.grid_x - left;
          const int row = point.grid_y - top;
          if (row < 0 || row >= 8 || col < 0 || col >= 8)
            continue;
          const int current = locations[row][col];
          if (current < 0 ||
              candidates[point.object_index].prob > candidates[current].prob ||
              point.residual < residuals[row][col]) {
            locations[row][col] = point.object_index;
            residuals[row][col] = point.residual;
          }
        }

        bool rows_seen[8] = {};
        bool columns_seen[8] = {};
        int detected = 0;
        float probability_sum = 0.f;
        float residual_sum = 0.f;
        for (int row = 0; row < 8; row++) {
          for (int col = 0; col < 8; col++) {
            const int index = locations[row][col];
            if (index < 0)
              continue;
            detected++;
            rows_seen[row] = true;
            columns_seen[col] = true;
            probability_sum += candidates[index].prob;
            residual_sum += residuals[row][col];
          }
        }
        if (detected < 48)
          continue;

        bool complete_axes = true;
        for (int i = 0; i < 8; i++)
          complete_axes = complete_axes && rows_seen[i] && columns_seen[i];
        if (!complete_axes)
          continue;

        const float expected_x0 = anchor_x + left * cell;
        const float expected_y0 = anchor_y + top * cell;
        bool ordered = true;
        for (int row = 0; row < 8 && ordered; row++) {
          for (int col = 0; col < 8; col++) {
            const int index = locations[row][col];
            if (index < 0)
              continue;
            const Object &object = candidates[index];
            const float expected_x = expected_x0 + col * cell;
            const float expected_y = expected_y0 + row * cell;
            if (std::fabs(object_cx(object) - expected_x) > cell * 0.35f ||
                std::fabs(object_cy(object) - expected_y) > cell * 0.35f) {
              ordered = false;
              break;
            }
          }
        }
        if (!ordered)
          continue;

        const float average_probability = probability_sum / detected;
        const float average_residual = residual_sum / detected;
        const int synthetic = 64 - detected;
        const float score = detected * 1000.f + average_probability * 100.f -
                            average_residual * 250.f - synthetic * 30.f;
        if (score <= best.score)
          continue;

        std::vector<Object> cells;
        cells.reserve(64);
        for (int row = 0; row < 8; row++) {
          for (int col = 0; col < 8; col++) {
            Object cell_object{};
            const int index = locations[row][col];
            if (index >= 0) {
              cell_object = candidates[index];
            } else {
              cell_object.label = 0;
              cell_object.prob = 0.01f;
            }
            cell_object.x = expected_x0 + col * cell - cell * 0.5f;
            cell_object.y = expected_y0 + row * cell - cell * 0.5f;
            cell_object.w = cell;
            cell_object.h = cell;
            cell_object.row = row;
            cell_object.col = col;
            cells.push_back(cell_object);
          }
        }

        best.valid = true;
        best.score = score;
        best.cells = std::move(cells);
      }
    }
  }
  return best;
}

static bool reconstruct_board_lattice(std::vector<Object> &squares) {
  if (squares.size() < 48)
    return false;

  std::vector<Object> candidates;
  candidates.reserve(squares.size());
  for (const Object &object : squares) {
    const float aspect = std::max(object.w, object.h) /
                         std::max(1.f, std::min(object.w, object.h));
    if (aspect <= 1.45f)
      candidates.push_back(object);
  }
  if (candidates.size() < 48)
    return false;

  const int count = (int)candidates.size();
  std::vector<int> parent(count);
  for (int i = 0; i < count; i++)
    parent[i] = i;

  for (int i = 0; i < count; i++) {
    for (int j = i + 1; j < count; j++) {
      const float length_i = object_cell_len(candidates[i]);
      const float length_j = object_cell_len(candidates[j]);
      const float cell = (length_i + length_j) * 0.5f;
      if (cell <= 2.f)
        continue;
      const float size_ratio =
          std::max(length_i, length_j) /
          std::max(1.f, std::min(length_i, length_j));
      if (size_ratio > 1.35f)
        continue;

      const float dx =
          std::fabs(object_cx(candidates[i]) - object_cx(candidates[j]));
      const float dy =
          std::fabs(object_cy(candidates[i]) - object_cy(candidates[j]));
      const bool horizontal_neighbor =
          dx > cell * 0.70f && dx < cell * 1.30f && dy < cell * 0.28f;
      const bool vertical_neighbor =
          dy > cell * 0.70f && dy < cell * 1.30f && dx < cell * 0.28f;
      if (horizontal_neighbor || vertical_neighbor)
        lattice_union(parent, i, j);
    }
  }

  LatticeFit best;
  for (int root = 0; root < count; root++) {
    if (lattice_find(parent, root) != root)
      continue;
    std::vector<int> indices;
    for (int i = 0; i < count; i++) {
      if (lattice_find(parent, i) == root)
        indices.push_back(i);
    }
    if (indices.size() < 48)
      continue;
    LatticeFit fit = fit_component_to_board(candidates, indices);
    if (fit.valid && fit.score > best.score)
      best = std::move(fit);
  }

  if (!best.valid)
    return false;
  squares = std::move(best.cells);
  return true;
}

static void assign_board_grid(std::vector<Object> &squares) {
  if (reconstruct_board_lattice(squares))
    return;
  if (squares.size() < 60)
    return;

  std::sort(squares.begin(), squares.end(),
            [](const Object &a, const Object &b) {
              const float center_a = object_cy(a);
              const float center_b = object_cy(b);
              if (std::fabs(center_a - center_b) > (a.h + b.h) * 0.25f)
                return center_a < center_b;
              return a.x < b.x;
            });
  const int count = std::min((int)squares.size(), 64);
  for (int i = 0; i < count; i++) {
    squares[i].row = i / 8;
    squares[i].col = i % 8;
  }
  if ((int)squares.size() > count)
    squares.erase(squares.begin() + count, squares.end());
}

static bool is_promotion_container(int label) {
  return label >= 14 && label <= 17;
}

static void apply_star_candidates(std::vector<Object> &squares,
                                  const std::vector<Object> &raw) {
  if (squares.size() != 64)
    return;

  for (const Object &candidate : raw) {
    if (candidate.label != 13 || candidate.prob < 0.20f)
      continue;

    Object *closest = nullptr;
    float best_distance = FLT_MAX;
    const float candidate_x = object_cx(candidate);
    const float candidate_y = object_cy(candidate);
    for (Object &square : squares) {
      if (square.row < 0 || square.col < 0)
        continue;
      const float distance =
          std::fabs(object_cx(square) - candidate_x) +
          std::fabs(object_cy(square) - candidate_y);
      if (distance < best_distance) {
        best_distance = distance;
        closest = &square;
      }
    }

    if (!closest || (closest->label != 0 && closest->label != 13))
      continue;

    const float cell = object_cell_len(*closest);
    const float star_len = object_cell_len(candidate);
    if (cell <= 1.f || star_len < cell * 0.08f ||
        star_len > cell * 0.90f) {
      continue;
    }

    const float margin = cell * 0.10f;
    if (candidate_x < closest->x - margin ||
        candidate_x > closest->x + closest->w + margin ||
        candidate_y < closest->y - margin ||
        candidate_y > closest->y + closest->h + margin) {
      continue;
    }

    if (closest->label != 13 || candidate.prob > closest->prob) {
      closest->label = 13;
      closest->prob = candidate.prob;
    }
  }
}

static std::vector<Object>
filter_recognition_squares(const std::vector<Object> &raw) {
  std::vector<Object> board_candidates;
  std::vector<Object> promotion_candidates;
  for (const Object &object : raw) {
    if (object.label >= 0 && object.label <= 12)
      board_candidates.push_back(object);
    else if (is_promotion_container(object.label) && object.prob >= 0.5f)
      promotion_candidates.push_back(object);
  }

  promotion_candidates =
      suppress_overlapping_any_label(std::move(promotion_candidates), 0.45f);
  if (!promotion_candidates.empty()) {
    promotion_candidates.resize(1);
    return promotion_candidates;
  }

  board_candidates = keep_square_like_candidates(board_candidates);
  board_candidates =
      suppress_overlapping_any_label(std::move(board_candidates), 0.45f);
  assign_board_grid(board_candidates);

  std::vector<Object> squares;
  squares.reserve(64);
  for (const Object &object : board_candidates) {
    if (object.row >= 0 && object.col >= 0)
      squares.push_back(object);
  }
  apply_star_candidates(squares, raw);
  std::sort(squares.begin(), squares.end(), [](const Object &a,
                                                const Object &b) {
    if (a.row != b.row)
      return a.row < b.row;
    return a.col < b.col;
  });
  return squares;
}

static bool board_bounds(const std::vector<Object> &squares, float &x0,
                         float &y0, float &x1, float &y1,
                         float &average_cell) {
  if (squares.size() != 64)
    return false;
  x0 = y0 = FLT_MAX;
  x1 = y1 = -FLT_MAX;
  average_cell = 0.f;
  for (const Object &square : squares) {
    if (square.row < 0 || square.row >= 8 || square.col < 0 ||
        square.col >= 8) {
      return false;
    }
    x0 = std::min(x0, square.x);
    y0 = std::min(y0, square.y);
    x1 = std::max(x1, square.x + square.w);
    y1 = std::max(y1, square.y + square.h);
    average_cell += object_cell_len(square);
  }
  average_cell /= 64.f;
  return true;
}

static bool make_board_crop(const std::vector<Object> &squares, int image_w,
                            int image_h, int &crop_x, int &crop_y,
                            int &crop_x2, int &crop_y2) {
  float x0, y0, x1, y1, average_cell;
  if (!board_bounds(squares, x0, y0, x1, y1, average_cell) ||
      average_cell < 4.f) {
    return false;
  }

  const float padding = std::max(8.f, average_cell * 0.35f);
  crop_x = (int)std::floor(std::max(0.f, x0 - padding));
  crop_y = (int)std::floor(std::max(0.f, y0 - padding));
  crop_x2 = (int)std::ceil(std::min((float)image_w, x1 + padding));
  crop_y2 = (int)std::ceil(std::min((float)image_h, y1 + padding));
  return crop_x2 - crop_x >= 100 && crop_y2 - crop_y >= 100;
}

static void map_crop_objects_to_original(std::vector<Object> &objects,
                                         int crop_x, int crop_y, int image_w,
                                         int image_h) {
  for (Object &object : objects) {
    float x0 = object.x + crop_x;
    float y0 = object.y + crop_y;
    float x1 = x0 + object.w;
    float y1 = y0 + object.h;
    object.x = std::max(0.f, std::min(x0, (float)image_w - 1));
    object.y = std::max(0.f, std::min(y0, (float)image_h - 1));
    x1 = std::max(0.f, std::min(x1, (float)image_w - 1));
    y1 = std::max(0.f, std::min(y1, (float)image_h - 1));
    object.w = x1 - object.x;
    object.h = y1 - object.y;
  }
}

static bool square_like_for_refine(const Object &object,
                                   float average_cell) {
  if (object.label < 0 || object.label > 13 || object.w <= 1.f ||
      object.h <= 1.f) {
    return false;
  }
  const float aspect = std::max(object.w, object.h) /
                       std::max(1.f, std::min(object.w, object.h));
  const float length_ratio =
      object_cell_len(object) / std::max(1.f, average_cell);
  return aspect <= 1.45f && length_ratio >= 0.45f && length_ratio <= 1.85f;
}

static void
refine_squares_with_second_pass(std::vector<Object> &squares,
                                const std::vector<Object> &second_raw) {
  float x0, y0, x1, y1, average_cell;
  if (!board_bounds(squares, x0, y0, x1, y1, average_cell))
    return;
  const float max_distance = std::max(8.f, average_cell * 0.65f);

  for (Object &square : squares) {
    const float square_area = std::max(1.f, square.w * square.h);
    float best_score = -FLT_MAX;
    const Object *best = nullptr;
    for (const Object &candidate : second_raw) {
      if (!square_like_for_refine(candidate, average_cell))
        continue;
      const float distance = std::fabs(object_cx(candidate) - object_cx(square)) +
                             std::fabs(object_cy(candidate) - object_cy(square));
      if (distance > max_distance)
        continue;
      const float overlap = intersection_area(square, candidate) / square_area;
      if (overlap < 0.25f)
        continue;
      const float score = candidate.prob + overlap * 0.5f -
                          distance / std::max(1.f, average_cell) * 0.15f;
      if (score > best_score) {
        best_score = score;
        best = &candidate;
      }
    }
    if (best) {
      square.label = best->label;
      square.prob = best->prob;
    }
  }
}

static bool try_reuse_native_cache(const unsigned char *pixels, int width,
                                   int height, int pass_count,
                                   std::vector<Object> &objects) {
  double compare_start_time = ncnn::get_current_time();

  std::lock_guard<std::mutex> lock(g_cache_mutex);

  if (!g_cache_valid || g_cached_objects.empty()) {
    set_cache_status("no cache");
    return false;
  }

  if (g_cached_pass_count != pass_count) {
    set_cache_status("pass changed");
    return false;
  }

  if (width != g_cached_bitmap_width || height != g_cached_bitmap_height) {
    set_cache_status("size changed");
    return false;
  }

  long long now = now_ms();
  if (now - g_last_real_detect_time_ms >= FORCE_DETECT_INTERVAL_MS) {
    set_cache_status("force refresh");
    return false;
  }

  uint8_t current_gray_samples[BOARD_GRAY_SAMPLE_COUNT];
  if (!compute_board_gray_samples(pixels, width, height, width * 3,
                                  g_cached_board_rect,
                                  current_gray_samples)) {
    set_cache_status("bad board gray samples");
    return false;
  }

  double min_cell_similarity = 1.0;
  int least_similar_cell = -1;
  int least_similar_changed_samples = 0;
  int least_similar_max_diff = 0;
  for (int cell = 0; cell < BOARD_GRID_SIZE * BOARD_GRID_SIZE; cell++) {
    int similar_samples = 0;
    int max_sample_diff = 0;
    int cell_offset = cell * BOARD_CELL_SAMPLE_COUNT;
    for (int sample = 0; sample < BOARD_CELL_SAMPLE_COUNT; sample++) {
      int diff = abs((int)current_gray_samples[cell_offset + sample] -
                     (int)g_cached_board_gray_samples[cell_offset + sample]);
      if (diff <= CACHE_SAMPLE_GRAY_DIFF_THRESHOLD)
        similar_samples++;
      if (diff > max_sample_diff)
        max_sample_diff = diff;
    }

    double similarity =
        (double)similar_samples / (double)BOARD_CELL_SAMPLE_COUNT;
    if (least_similar_cell < 0 || similarity < min_cell_similarity) {
      min_cell_similarity = similarity;
      least_similar_cell = cell;
      least_similar_changed_samples =
          BOARD_CELL_SAMPLE_COUNT - similar_samples;
      least_similar_max_diff = max_sample_diff;
    }

    if (similarity < CACHE_MIN_CELL_GRAY_SIMILARITY) {
      char status[192];
      snprintf(status, sizeof(status),
               "changed cell %d similarity %.1f%% changed %d/%d max %d "
               "compare %.2f ms",
               cell, similarity * 100.0,
               BOARD_CELL_SAMPLE_COUNT - similar_samples,
               BOARD_CELL_SAMPLE_COUNT, max_sample_diff,
               ncnn::get_current_time() - compare_start_time);
      set_cache_status(status);
      return false;
    }
  }

  double current_feature[BOARD_GRID_SIZE * BOARD_GRID_SIZE];
  if (!compute_board_feature(pixels, width, height, width * 3,
                             g_cached_board_rect, current_feature)) {
    set_cache_status("bad board rect");
    return false;
  }

  double total_diff = 0.0;
  double max_cell_diff = 0.0;
  for (int i = 0; i < BOARD_GRID_SIZE * BOARD_GRID_SIZE; i++) {
    double diff = fabs(current_feature[i] - g_cached_board_feature[i]);
    total_diff += diff;
    if (diff > max_cell_diff)
      max_cell_diff = diff;
  }

  double avg_diff = total_diff / (BOARD_GRID_SIZE * BOARD_GRID_SIZE);
  bool reuse = avg_diff <= CACHE_AVG_DIFF_THRESHOLD &&
               max_cell_diff <= CACHE_MAX_CELL_DIFF_THRESHOLD;

  char status[192];
  snprintf(status, sizeof(status),
           "%s similarity %.1f%% cell %d changed %d/%d sampleMax %d avg "
           "%.2f max %.2f compare %.2f ms",
           reuse ? "reused" : "changed", min_cell_similarity * 100.0,
           least_similar_cell, least_similar_changed_samples,
           BOARD_CELL_SAMPLE_COUNT, least_similar_max_diff, avg_diff,
           max_cell_diff, ncnn::get_current_time() - compare_start_time);
  set_cache_status(status);

  if (!reuse)
    return false;

  objects = g_cached_objects;
  return true;
}

static void update_native_cache(const unsigned char *pixels, int width,
                                int height, int pass_count,
                                const std::vector<Object> &objects) {
  std::lock_guard<std::mutex> lock(g_cache_mutex);
  std::string previous_status = g_last_cache_status;

  if (!is_valid_board(objects)) {
    clear_native_cache_locked();
    set_cache_status("not valid board");
    return;
  }

  RectFNative board_rect;
  if (!build_board_rect(objects, width, height, board_rect)) {
    clear_native_cache_locked();
    set_cache_status("bad board rect");
    return;
  }

  double board_feature[BOARD_GRID_SIZE * BOARD_GRID_SIZE];
  bool feature_ok = compute_board_feature(pixels, width, height, width * 3,
                                          board_rect, board_feature);
  if (!feature_ok) {
    clear_native_cache_locked();
    set_cache_status("bad board feature");
    return;
  }

  uint8_t board_gray_samples[BOARD_GRAY_SAMPLE_COUNT];
  bool samples_ok = compute_board_gray_samples(
      pixels, width, height, width * 3, board_rect, board_gray_samples);
  if (!samples_ok) {
    clear_native_cache_locked();
    set_cache_status("bad board gray samples");
    return;
  }

  g_cache_valid = true;
  g_cached_pass_count = pass_count;
  g_cached_objects = objects;
  g_cached_board_rect = board_rect;
  memcpy(g_cached_board_feature, board_feature, sizeof(g_cached_board_feature));
  memcpy(g_cached_board_gray_samples, board_gray_samples,
         sizeof(g_cached_board_gray_samples));
  g_cached_bitmap_width = width;
  g_cached_bitmap_height = height;
  g_last_real_detect_time_ms = now_ms();
  if (previous_status.empty() || previous_status == "updated")
    set_cache_status("updated");
  else
    set_cache_status(previous_status + "; updated");
}

int ABI yolov5ncnn_init() {
  std::call_once(g_cpu_init_flag, []() {
    ncnn::Option opt;
    opt.lightmode = true;
    opt.num_threads = 4;
    opt.blob_allocator = &g_blob_pool_allocator;
    opt.workspace_allocator = &g_workspace_pool_allocator;
    opt.use_packing_layout = true;
#ifdef __ANDROID__
    ncnn::set_cpu_powersave(2);
    opt.num_threads = 2;
#endif

    opt.use_vulkan_compute = false;
    yolov11.opt = opt;

    std::vector<char> param(yolov8_param_len + 1, '\0');
    memcpy(param.data(), yolov8_param, yolov8_param_len);
    int param_result = yolov11.load_param_mem(param.data());
    int model_result =
        param_result == 0 ? yolov11.load_model(yolov8_bin) : -1;
    // The memory overload returns the number of model bytes consumed.
    g_cpu_init_result = param_result == 0 && model_result > 0 ? 0 : -1;
  });
  return g_cpu_init_result == 0 ? 1 : 0;
}

int ABI yolov5ncnn_set_backend(int backend, const char *model_dir) {
  if (backend != YOLOV5NCNN_BACKEND_CPU &&
      backend != YOLOV5NCNN_BACKEND_NPU)
    return 0;
  (void)model_dir;

  std::lock_guard<std::mutex> detect_lock(detectMutex);
  // Keep accepting the legacy NPU value for API compatibility. All accepted
  // backend requests now use the bundled NCNN model.
  if (!yolov5ncnn_init())
    return 0;

  {
    std::lock_guard<std::mutex> cache_lock(g_cache_mutex);
    clear_native_cache_locked();
    set_cache_status("backend changed");
  }
  return 1;
}

string position2fen(vector<PositionInfo> &objects) {
  string fen = "";

  if (objects.size() == 64) {
    string temp_str = "";
    int empty_num = 0;

    for (int x = 0; x < 8; x++) {
      for (int y = 0; y < 8; y++) {
        auto san = objects[x * 8 + y].san;
        if (san == "") {
          empty_num++;
        } else {
          if (empty_num >= 1) {
            temp_str += to_string(empty_num);
            empty_num = 0;
          }
          temp_str += san;
        }
      }

      if (empty_num >= 1) {
        temp_str += to_string(empty_num);
      }
      if (x < 7) {
        temp_str += "/";
      }
      fen += temp_str;
      temp_str = "";
      empty_num = 0;
    }
  }
  return fen;
}

static vector<PositionInfo> objects_to_position_infos(
    const std::vector<Object> &objects) {
  vector<PositionInfo> outObj = {};

  for (size_t i = 0; i < objects.size(); i++) {

    if (objects[i].label < 14) {
      PositionInfo o;
      o.x = objects[i].x;
      o.y = objects[i].y;
      o.w = objects[i].w;
      o.h = objects[i].h;
      o.label = class_names[objects[i].label];
      o.san = san_names[objects[i].label];
      o.prob = objects[i].prob;

      outObj.push_back(o);

    } else if (objects[i].label >= 14 && objects[i].label < 18) {
      for (int j = 0; j < 4; j++) {
        PositionInfo o;
        o.x = objects[i].x;
        o.y = objects[i].y + j * (objects[i].h / 4);
        o.w = objects[i].w;
        o.h = objects[i].h / 4;
        o.label = promote_name[objects[i].label - 14][j];
        o.san = san_names[objects[i].label];
        o.prob = objects[i].prob;

        outObj.push_back(o);
      }
    } else if (objects[i].label >= 18 && objects[i].label < 26) {
      PositionInfo o;
      o.x = objects[i].x;
      o.y = objects[i].y;
      o.w = objects[i].w;
      o.h = objects[i].h;
      o.label = class_names[objects[i].label];
      o.san = san_names[objects[i].label];
      o.prob = objects[i].prob;

      outObj.push_back(o);
    }
  }

  return outObj;
}

static vector<PositionInfo>
yolov5ncnn_detect_with_passes(uint8_t *pixels, int width, int height,
                              int pass_count) {

  lock_guard<std::mutex> lock(detectMutex);

  if (!pixels || width <= 0 || height <= 0 ||
      (pass_count != DETECT_PASS_SINGLE &&
       pass_count != DETECT_PASS_DOUBLE) ||
      !yolov5ncnn_init()) {
    return {};
  }

  std::vector<Object> squares;
  if (try_reuse_native_cache(pixels, width, height, pass_count, squares))
    return objects_to_position_infos(squares);

  // First pass: detect on full image
  ncnn::Mat full_rgb =
      ncnn::Mat::from_pixels(pixels, ncnn::Mat::PIXEL_BGR2RGB, width, height);

  std::vector<Object> first_raw;
  runYoloInference(full_rgb, width, height, first_raw);

  squares = filter_recognition_squares(first_raw);

  if (!squares.empty() && is_promotion_container(squares.front().label)) {
    {
      std::lock_guard<std::mutex> cache_lock(g_cache_mutex);
      clear_native_cache_locked();
    }
    return objects_to_position_infos(squares);
  }

  int crop_x = 0;
  int crop_y = 0;
  int crop_x2 = 0;
  int crop_y2 = 0;
  if (pass_count == DETECT_PASS_DOUBLE &&
      make_board_crop(squares, width, height, crop_x, crop_y, crop_x2,
                      crop_y2)) {
    const int crop_w = crop_x2 - crop_x;
    const int crop_h = crop_y2 - crop_y;
    ncnn::Mat crop_rgb;
    ncnn::copy_cut_border(full_rgb, crop_rgb, crop_y, height - crop_y2,
                          crop_x, width - crop_x2);

    std::vector<Object> second_raw;
    runYoloInference(crop_rgb, crop_w, crop_h, second_raw);
    if (!second_raw.empty()) {
      map_crop_objects_to_original(second_raw, crop_x, crop_y, width, height);
      refine_squares_with_second_pass(squares, second_raw);
      apply_star_candidates(squares, first_raw);
      apply_star_candidates(squares, second_raw);
    }
  }

  update_native_cache(pixels, width, height, pass_count, squares);
  return objects_to_position_infos(squares);
}

vector<PositionInfo> yolov5ncnn_detect(uint8_t *pixels, int width,
                                       int height) {
  return yolov5ncnn_detect_with_passes(pixels, width, height,
                                      DETECT_PASS_DOUBLE);
}

static string yolov5ncnn_detect_json_with_passes(uint8_t *pixels, int width,
                                                 int height, int pass_count) {

  auto objects =
      yolov5ncnn_detect_with_passes(pixels, width, height, pass_count);

  if (objects.empty()) {
    return "";
  }

  vector<json> json_obj = {};

  for (size_t i = 0; i < objects.size(); i++) {

    json o = {};
    o["x"] = objects[i].x;
    o["y"] = objects[i].y;
    o["w"] = objects[i].w;
    o["h"] = objects[i].h;
    o["label"] = objects[i].label;
    o["prob"] = objects[i].prob;

    json_obj.push_back(o);
  }

  json outJson = {};

  outJson["fen"] = position2fen(objects);
  outJson["position"] = json_obj;

  return outJson.dump();
}

string yolov5ncnn_detect_json(uint8_t *pixels, int width, int height) {
  return yolov5ncnn_detect_json_with_passes(pixels, width, height,
                                           DETECT_PASS_DOUBLE);
}

string yolov5ncnn_detect_fen(uint8_t *pixels, int width, int height) {

  auto objects = yolov5ncnn_detect(pixels, width, height);

  return position2fen(objects);
}

char *ABI yolov5ncnn_detect_pixie_json(uint8_t *pixels, int width, int height) {

  auto json = yolov5ncnn_detect_json(pixels, width, height);

  auto res_length = json.size();

  char *res = (char *)malloc(res_length + 1 * sizeof(char));

  if (json.size() >= 1) {
    memcpy(res, json.c_str(), res_length);
  }
  res[res_length] = '\0';
  return res;
}

char *ABI yolov5ncnn_detect_file_json(uint8_t *file, int length) {
  std::vector<uint8_t> buffer(file, file + length);
  cv::Mat image = cv::imdecode(buffer, cv::IMREAD_COLOR);

  auto res = yolov5ncnn_detect_pixie_json(image.data, image.cols, image.rows);

  return res;
}

char *ABI yolov5ncnn_detect_pixie_fen(uint8_t *pixels, int width, int height) {

  auto fen = yolov5ncnn_detect_fen(pixels, width, height);

  auto res_length = fen.size();

  char *res = (char *)malloc(res_length + 1 * sizeof(char));

  if (fen.size() >= 1) {
    memcpy(res, fen.c_str(), res_length);
  }
  res[res_length] = '\0';
  return res;
}

char *ABI yolov5ncnn_detect_file_fen(uint8_t *file, int length) {
  std::vector<uint8_t> buffer(file, file + length);
  cv::Mat image = cv::imdecode(buffer, cv::IMREAD_COLOR);

  auto res = yolov5ncnn_detect_pixie_fen(image.data, image.cols, image.rows);

  return res;
}

void ABI free_string(char *p) {
  if (p) {
    free(p);
  }
}

#ifdef __ANDROID__
#include <jni.h>

static jstring detect_file_json_jni(JNIEnv *env, jbyteArray file_data) {
  jsize length = env->GetArrayLength(file_data);
  jbyte *buffer = env->GetByteArrayElements(file_data, nullptr);
  char *result_c_str = yolov5ncnn_detect_file_json(
      reinterpret_cast<uint8_t *>(buffer), (int)length);
  jstring result_java = nullptr;
  if (result_c_str != nullptr) {
    result_java = env->NewStringUTF(result_c_str);
    free_string(result_c_str);
  }
  env->ReleaseByteArrayElements(file_data, buffer, JNI_ABORT);
  return result_java;
}

static jstring detect_argb_json_jni(JNIEnv *env, jintArray pixel_data,
                                    jint width, jint height,
                                    jint pass_count) {
  if (pixel_data == nullptr || width <= 0 || height <= 0 ||
      (pass_count != DETECT_PASS_SINGLE &&
       pass_count != DETECT_PASS_DOUBLE)) {
    return nullptr;
  }

  const long long pixel_count = (long long)width * (long long)height;
  if (pixel_count <= 0 || pixel_count > env->GetArrayLength(pixel_data)) {
    return nullptr;
  }

  jint *argb_pixels = env->GetIntArrayElements(pixel_data, nullptr);
  if (argb_pixels == nullptr) {
    return nullptr;
  }

  std::vector<uint8_t> bgr_pixels((size_t)pixel_count * 3);
  for (long long i = 0; i < pixel_count; i++) {
    const uint32_t argb = (uint32_t)argb_pixels[i];
    bgr_pixels[(size_t)i * 3] = (uint8_t)(argb & 0xff);
    bgr_pixels[(size_t)i * 3 + 1] = (uint8_t)((argb >> 8) & 0xff);
    bgr_pixels[(size_t)i * 3 + 2] = (uint8_t)((argb >> 16) & 0xff);
  }
  env->ReleaseIntArrayElements(pixel_data, argb_pixels, JNI_ABORT);

  std::string result = yolov5ncnn_detect_json_with_passes(
      bgr_pixels.data(), (int)width, (int)height, (int)pass_count);
  return env->NewStringUTF(result.c_str());
}

static jint set_backend_jni(JNIEnv *env, jint backend, jstring model_dir) {
  const char *model_dir_chars =
      model_dir ? env->GetStringUTFChars(model_dir, nullptr) : nullptr;
  int result = yolov5ncnn_set_backend((int)backend, model_dir_chars);
  if (model_dir_chars)
    env->ReleaseStringUTFChars(model_dir, model_dir_chars);
  return (jint)result;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_chessnut_chessnut_NativeVision_yolov5ncnn_1detect_1file_1json(
    JNIEnv *env, jobject thiz, jbyteArray file_data) {
  return detect_file_json_jni(env, file_data);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_chessnut_chessnutnext_NativeVision_yolov5ncnnDetectFileJson(
    JNIEnv *env, jobject thiz, jbyteArray file_data) {
  return detect_file_json_jni(env, file_data);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_chessnut_chessnutnext_NativeVision_yolov5ncnnDetectArgbJson(
    JNIEnv *env, jobject thiz, jintArray pixel_data, jint width, jint height) {
  return detect_argb_json_jni(env, pixel_data, width, height,
                              DETECT_PASS_DOUBLE);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_chessnut_chessnutnext_NativeVision_yolov5ncnnDetectArgbJsonWithPasses(
    JNIEnv *env, jobject thiz, jintArray pixel_data, jint width, jint height,
    jint pass_count) {
  return detect_argb_json_jni(env, pixel_data, width, height, pass_count);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_chessnut_chessnut_NativeVision_yolov5ncnn_1set_1backend(
    JNIEnv *env, jobject thiz, jint backend, jstring model_dir) {
  return set_backend_jni(env, backend, model_dir);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_chessnut_chessnutnext_NativeVision_yolov5ncnnSetBackend(
    JNIEnv *env, jobject thiz, jint backend, jstring model_dir) {
  return set_backend_jni(env, backend, model_dir);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_chessnut_chessnut_NativeVision_yolov5ncnn_1init(JNIEnv *env,
                                                         jobject thiz) {
  return (jint)yolov5ncnn_init();
}

extern "C" JNIEXPORT jint JNICALL
Java_com_chessnut_chessnutnext_NativeVision_yolov5ncnnInit(JNIEnv *env,
                                                           jobject thiz) {
  return (jint)yolov5ncnn_init();
}

#endif

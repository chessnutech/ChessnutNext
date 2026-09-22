#include <stdlib.h>
#include <string.h>

static char *copy_result(const char *value) {
  const size_t length = strlen(value);
  char *result = (char *)malloc(length + 1);
  if (result == NULL) {
    return NULL;
  }
  memcpy(result, value, length + 1);
  return result;
}

int yolov5ncnn_init(void) { return 0; }

int yolov5ncnn_set_backend(int backend, const char *model_dir) {
  (void)model_dir;
  return backend == 0 || backend == 1;
}

char *yolov5ncnn_detect_pixie_json(unsigned char *pixels, int w, int h) {
  (void)pixels;
  (void)w;
  (void)h;
  return copy_result("");
}

char *yolov5ncnn_detect_pixie_fen(unsigned char *pixels, int w, int h) {
  (void)pixels;
  (void)w;
  (void)h;
  return copy_result("");
}

char *yolov5ncnn_detect_file_json(unsigned char *file, int length) {
  (void)file;
  (void)length;
  return copy_result("");
}

char *yolov5ncnn_detect_file_fen(unsigned char *file, int length) {
  (void)file;
  (void)length;
  return copy_result("");
}

void free_string(char *value) { free(value); }

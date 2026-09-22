#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
#define EXTERN_FLAGS __declspec(dllexport)
#else
#define EXTERN_FLAGS
#endif

#ifdef _WIN32
#define ABI __cdecl
#else
#define ABI
#endif

#define YOLOV5NCNN_BACKEND_CPU 0
#define YOLOV5NCNN_BACKEND_NPU 1

EXTERN_FLAGS int ABI yolov5ncnn_init();
// Both published backend values are retained for API compatibility. Requests
// for the legacy NPU backend transparently use the default NCNN backend;
// model_dir is ignored.
EXTERN_FLAGS int ABI yolov5ncnn_set_backend(int backend,
                                           const char *model_dir);
EXTERN_FLAGS char *ABI yolov5ncnn_detect_pixie_json(uint8_t *pixels, int w,
                                                    int h);
EXTERN_FLAGS char *ABI yolov5ncnn_detect_pixie_fen(uint8_t *pixels, int w,
                                                    int h);

EXTERN_FLAGS char *ABI yolov5ncnn_detect_file_json(uint8_t *file, int length);

EXTERN_FLAGS char *ABI yolov5ncnn_detect_file_fen(uint8_t *file, int length);
EXTERN_FLAGS void ABI free_string(char *);

#ifdef __cplusplus
}
#endif

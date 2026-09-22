#include "vision.h"
#include <cstdlib>
#include <iostream>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>

using namespace std;
int main() {
  cout << "init: " << yolov5ncnn_init() << endl;

  int width, height, channels;

  auto file = "test1.jpg";

  cv::Mat mat = cv::imread(file, 1);

  auto json = yolov5ncnn_detect_pixie_json(mat.data, mat.cols, mat.rows);

  cout << "json: " << json << endl;

  free(json);
}

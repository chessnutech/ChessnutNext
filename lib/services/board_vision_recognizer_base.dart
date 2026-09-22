abstract class BoardVisionFenRecognizer {
  Future<String?> recognizeFen(List<int> imageBytes);

  Future<String?> recognizeJson(List<int> imageBytes);
}

// Web-specific adapter setup
import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';

void setupWebAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter();
}


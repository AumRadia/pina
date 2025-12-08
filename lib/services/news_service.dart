import 'dart:async';
import 'dart:convert';
import "package:http/http.dart" as http;
import 'package:pina/models/news_article.dart';
import 'package:pina/screens/constants.dart';

// Lightweight wrapper around NewsData.io public API.
class Apiservice {
  final String baseurl =
      "https://newsdata.io/api/1/latest?"
      "apikey=${ApiConstants.newsDataKey}"
      "&language=en"
      "&category=top";

  // Fetches the latest feed and maps it into strongly typed models.
  Future<List<NewsArticle>> fetchNews() async {
    final response = await http
        .get(Uri.parse(baseurl))
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw TimeoutException("News API timed out. Please retry.");
          },
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["results"] == null) return [];
      List articles = data["results"];

      return articles.map((e) => NewsArticle.fromJson(e)).toList();
    } else {
      throw Exception("Failed");
    }
  }
}

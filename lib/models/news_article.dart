// Immutable representation of a single card in the news list.
class NewsArticle {
  final String articleid;
  final String link;
  final String title;
  final String description;

  final List<dynamic> keywords;
  final List<dynamic> creator;

  final String language;
  final List<dynamic> country;
  final List<dynamic> category;

  final String pubdate;
  final String pubdatetz;

  final String imageurl;

  final String sourceid;
  final String sourcename;
  final int sourcepriority;
  final String sourceurl;
  final String sourceicon;

  final bool duplicate;

  NewsArticle({
    required this.articleid,
    required this.link,
    required this.title,
    required this.description,
    required this.keywords,
    required this.creator,
    required this.language,
    required this.country,
    required this.category,
    required this.pubdate,
    required this.pubdatetz,
    required this.imageurl,
    required this.sourceid,
    required this.sourcename,
    required this.sourcepriority,
    required this.sourceurl,
    required this.sourceicon,
    required this.duplicate,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    // Normalizes nullable array-like fields.
    List<dynamic> toList(dynamic v) {
      if (v == null) return [];
      return List<dynamic>.from(v);
    }

    return NewsArticle(
      articleid: json['article_id']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',

      keywords: toList(json['keywords']),
      creator: toList(json['creator']),

      language: json['language']?.toString() ?? '',
      country: toList(json['country']),
      category: toList(json['category']),

      pubdate: json['pubDate']?.toString() ?? '',
      pubdatetz: json['pubDateTZ']?.toString() ?? '',

      imageurl: json['image_url']?.toString() ?? '',

      sourceid: json['source_id']?.toString() ?? '',
      sourcename: json['source_name']?.toString() ?? '',
      sourcepriority:
          int.tryParse(json['source_priority']?.toString() ?? '0') ?? 0,
      sourceurl: json['source_url']?.toString() ?? '',
      sourceicon: json['source_icon']?.toString() ?? '',

      duplicate: json['duplicate'] == true,
    );
  }
}

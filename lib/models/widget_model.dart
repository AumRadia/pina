// Marketplace listing that mirrors the MongoDB document.
class MarketWidget {
  final String id;
  final String visitCategory;
  final String visitName; // The display name
  final String widgetVendor;
  final String widgetPaidOrFree; // "paid" or "free"
  final int visitCostPerUnit;
  final String visitStatus;

  MarketWidget({
    required this.id,
    required this.visitCategory,
    required this.visitName,
    required this.widgetVendor,
    required this.widgetPaidOrFree,
    required this.visitCostPerUnit,
    required this.visitStatus,
  });

  // Factory to convert JSON from Node.js into this Dart object
  factory MarketWidget.fromJson(Map<String, dynamic> json) {
    return MarketWidget(
      id: json['_id'] ?? '', // MongoDB uses _id
      visitCategory: json['visitCategory'] ?? 'Uncategorized',
      visitName: json['visitName'] ?? 'Unknown Widget',
      widgetVendor: json['widgetVendor'] ?? '',
      widgetPaidOrFree: json['widgetPaidOrFree'] ?? 'free',
      visitCostPerUnit: json['visitCostPerUnit'] ?? 0,
      visitStatus: json['visitStatus'] ?? 'active',
    );
  }
}

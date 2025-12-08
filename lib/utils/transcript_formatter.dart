class TranscriptFormatter {
  static String formatTranscriptOutput(Map<String, dynamic> data) {
    if (data.containsKey("error")) return "Error: ${data['error']}";

    StringBuffer buffer = StringBuffer();

    // 1. The Main Transcript
    buffer.writeln("=== TRANSCRIPT ===");
    buffer.writeln(data['text'] ?? "No text found.");
    buffer.writeln();

    // 2. Summary (if enabled)
    if (data['summary'] != null) {
      buffer.writeln("=== SUMMARY ===");
      buffer.writeln(data['summary']);
      buffer.writeln();
    }

    // 3. Auto Chapters
    if (data['chapters'] != null) {
      buffer.writeln("=== CHAPTERS ===");
      final List chapters = data['chapters'];
      if (chapters.isEmpty) {
        buffer.writeln("No chapters detected.");
      } else {
        for (var chapter in chapters) {
          final start = (chapter['start'] / 1000).toStringAsFixed(1);
          final end = (chapter['end'] / 1000).toStringAsFixed(1);
          buffer.writeln("• [${start}s - ${end}s] ${chapter['headline']}");
          buffer.writeln("  ${chapter['summary']}");
          buffer.writeln();
        }
      }
      buffer.writeln();
    }

    // 4. Auto Highlights
    if (data['auto_highlights_result'] != null &&
        data['auto_highlights_result']['results'] != null) {
      buffer.writeln("=== KEY HIGHLIGHTS ===");
      final List results = data['auto_highlights_result']['results'];
      if (results.isEmpty) {
        buffer.writeln("No highlights detected.");
      } else {
        for (var item in results) {
          buffer.writeln("• ${item['text']} (Count: ${item['count']})");
        }
      }
      buffer.writeln();
    }

    // 5. Content Safety
    if (data['content_safety_labels'] != null &&
        data['content_safety_labels']['results'] != null) {
      final List results = data['content_safety_labels']['results'];
      if (results.isNotEmpty) {
        buffer.writeln("=== CONTENT SAFETY FLAGS ===");
        for (var item in results) {
          buffer.writeln(
            "⚠ ${item['text']}: ${item['labels'][0]['label']} (${(item['labels'][0]['confidence'] * 100).toStringAsFixed(1)}%)",
          );
        }
        buffer.writeln();
      }
    }

    // 6. Sentiment Analysis
    if (data['sentiment_analysis_results'] != null) {
      buffer.writeln("=== SENTIMENT ANALYSIS ===");
      final List sentiments = data['sentiment_analysis_results'];
      int positive = 0;
      int negative = 0;
      int neutral = 0;

      for (var s in sentiments) {
        if (s['sentiment'] == 'POSITIVE')
          positive++;
        else if (s['sentiment'] == 'NEGATIVE')
          negative++;
        else
          neutral++;
      }

      buffer.writeln("Overall Sentiment Breakdown:");
      buffer.writeln("😊 Positive: $positive sentences");
      buffer.writeln("😐 Neutral:  $neutral sentences");
      buffer.writeln("😟 Negative: $negative sentences");
    }

    return buffer.toString();
  }
}

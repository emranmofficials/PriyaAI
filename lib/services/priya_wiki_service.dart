import 'dart:convert';
import 'package:http/http.dart' as http;

/// Instant Knowledge & Fact Retrieval Engine.
/// 100% mirrors Maya's `com.getmaya.android.data.wiki.WikiWorker`.
///
/// Fetches immediate, accurate summaries from Bengali & English Wikipedia
/// and DuckDuckGo for factual, scientific, historical, or geographical queries
/// without requiring heavy LLM tokens.
class PriyaWikiService {
  PriyaWikiService._();
  static final PriyaWikiService instance = PriyaWikiService._();

  final http.Client _client = http.Client();

  /// Checks if query is a factual question suitable for instant wiki lookup.
  bool isFactQuery(String text) {
    final lower = text.trim().toLowerCase();
    final factKeywords = [
      'কী', 'কি', 'কাকে বলে', 'কোথায়', 'কবে', 'কে আবিষ্কার', 'জনসংখ্যা',
      'ইতিহাস', 'রাজধানী', 'অর্থ কি', 'মানে কি', 'কীভাবে', 'what is',
      'who is', 'where is', 'when was', 'capital of', 'meaning of'
    ];
    return factKeywords.any((kw) => lower.contains(kw));
  }

  /// Extracts the main topic title from the user's question.
  String extractTopic(String query) {
    var clean = query.trim()
        .replaceAll(RegExp(r'^(বলো তো|বলতো|জানো কি|আমাকে বলো)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(সম্পর্কে বলো|সম্পর্কে কিছু বলো|কাকে বলে|কি|কী|কোথায়|কবে|কে|কীভাবে)\??$', caseSensitive: false), '')
        .trim();
    return clean.isEmpty ? query : clean;
  }

  /// Searches Bengali Wikipedia first, then falls back to English.
  Future<String?> lookupFact(String query) async {
    final topic = extractTopic(query);
    if (topic.isEmpty) return null;

    // 1. Try Bengali Wikipedia
    final bnResult = await _queryWikipedia(topic, 'bn');
    if (bnResult != null && bnResult.isNotEmpty) return bnResult;

    // 2. Try English Wikipedia
    final enResult = await _queryWikipedia(topic, 'en');
    if (enResult != null && enResult.isNotEmpty) return enResult;

    // 3. Fallback to DuckDuckGo Instant Answer
    return await _queryDuckDuckGo(topic);
  }

  Future<String?> _queryWikipedia(String topic, String lang) async {
    try {
      final uri = Uri.parse(
        'https://$lang.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(topic)}',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final extract = data['extract'] as String?;
        if (extract != null && extract.isNotEmpty) {
          // Truncate to first 2-3 sentences for concise speech
          final sentences = extract.split(RegExp(r'[।\.]\s+'));
          return sentences.take(2).join('। ') + '।';
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _queryDuckDuckGo(String topic) async {
    try {
      final uri = Uri.parse(
        'https://api.duckduckgo.com/?q=${Uri.encodeComponent(topic)}&format=json&no_html=1&skip_disambig=1',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final abstractText = data['AbstractText'] as String?;
        if (abstractText != null && abstractText.isNotEmpty) {
          return abstractText;
        }
      }
    } catch (_) {}
    return null;
  }
}

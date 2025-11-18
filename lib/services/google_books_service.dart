// lib/services/google_books_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint用
import 'package:http/http.dart' as http;

/// Google Books APIを使ってISBNやタイトルから書籍情報を取得するサービスクラス
class GoogleBooksApiService {
  /// ISBNを渡すと、対応する書籍情報を取得する
  /// 見つからなければ null を返す
  /// 返却される Map のキーは Books テーブルのカラム名に対応
  static Future<Map<String, dynamic>?> fetchBookInfoByIsbn(String isbn) async {
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['totalItems'] > 0) {
          final volumeInfo = data['items'][0]['volumeInfo'];

          final displayTitle = volumeInfo['title'] ?? '';
          final subtitle = volumeInfo['subtitle'] ?? '';
          final officialTitle = subtitle.isNotEmpty
              ? '$displayTitle: $subtitle'
              : displayTitle;

          final authorsRaw = volumeInfo['authors'];
          String author;
          if (authorsRaw is List) {
            author = authorsRaw.join(', ');
          } else if (authorsRaw is String) {
            author = authorsRaw;
          } else {
            author = '';
          }

          final publisher = volumeInfo['publisher'] ?? '';
          final pageCount = volumeInfo['pageCount'];

          String? thumbnailUrl;
          if (volumeInfo['imageLinks'] != null &&
              volumeInfo['imageLinks']['thumbnail'] != null) {
            thumbnailUrl = volumeInfo['imageLinks']['thumbnail'] as String?;
            if (thumbnailUrl != null) {
              thumbnailUrl = thumbnailUrl.replaceAll('http://', 'https://');
            }
          }

          const education = '';
          const subject = '';

          return {
            'display_title': displayTitle,
            'official_title': officialTitle,
            'author': author,
            'publisher': publisher,
            'thumbnail_url': thumbnailUrl,
            'page_count': pageCount,
            'education': education,
            'subject': subject,
            'isbn': isbn,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': null,
          };
        }
      } else {
        debugPrint(
          'Google Books API error: status code ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Google Books API exception: $e');
    }

    return null;
  }

  /// 書籍名（タイトル）で部分検索し、候補リストを返す
  /// 戻り値はMapのリストで、最低限 'display_title', 'isbn', 'authors' などを含む想定
  /// APIレスポンスのitemsをマッピングして返す
  static Future<List<Map<String, dynamic>>> searchBooksByTitle(
    String title,
  ) async {
    if (title.trim().isEmpty) return [];

    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=intitle:${Uri.encodeQueryComponent(title)}&maxResults=10',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['totalItems'] > 0 && data['items'] != null) {
          // itemsをMap<String, dynamic>のリストに変換
          final List<Map<String, dynamic>> results = [];

          for (final item in data['items']) {
            final volumeInfo = item['volumeInfo'];

            final displayTitle = volumeInfo['title'] ?? '';
            final subtitle = volumeInfo['subtitle'] ?? '';
            final fullTitle = subtitle.isNotEmpty
                ? '$displayTitle: $subtitle'
                : displayTitle;

            final authorsList = volumeInfo['authors'];
            final authors = (authorsList is List)
                ? authorsList.join(', ')
                : (authorsList ?? '');

            // ISBN取得（industryIdentifiersから13桁ISBN優先）
            String isbn = '';
            if (volumeInfo['industryIdentifiers'] != null) {
              for (final id in volumeInfo['industryIdentifiers']) {
                if (id['type'] == 'ISBN_13') {
                  isbn = id['identifier'];
                  break;
                } else if (id['type'] == 'ISBN_10' && isbn.isEmpty) {
                  isbn = id['identifier'];
                }
              }
            }

            results.add({
              'display_title': fullTitle,
              'title': displayTitle,
              'authors': authors,
              'isbn': isbn,
            });
          }

          return results;
        }
      } else {
        debugPrint(
          'Google Books API error (title search): status code ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Google Books API exception (title search): $e');
    }

    return [];
  }
}

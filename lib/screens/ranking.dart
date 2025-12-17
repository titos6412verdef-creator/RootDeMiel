import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'my_picks_detail.dart';
import 'book_hash.dart';

/// おすすめランキング画面
/// 「人気教材セット」と「人気レビュー」の2タブで表示
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // タブ数: 2
      child: Scaffold(
        appBar: AppBar(
          title: const Text('おすすめ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '人気教材セット'),
              Tab(text: '人気レビュー'),
            ],
          ),
        ),
        // タブ切替で表示するコンテンツ
        body: const TabBarView(
          children: [
            _RankingList(title: '人気教材セット', isMyPicks: false),
            _RankingList(title: '人気レビュー', isMyPicks: true),
          ],
        ),
      ),
    );
  }
}

/// タブごとのランキングリスト
/// title: タブ名
/// isMyPicks: 人気レビューかどうか
class _RankingList extends StatelessWidget {
  final String title;
  final bool isMyPicks;

  const _RankingList({required this.title, required this.isMyPicks});

  @override
  Widget build(BuildContext context) {
    // ------------------------
    // 「人気教材セット」ランキング（book_hash単位のいいね数）
    // ------------------------
    if (title == '人気教材セット') {
      return FutureBuilder<List<Map<String, dynamic>>>(
        // DBから教材セットの情報といいね数を取得
        future: DatabaseHelper.instance.getBookSetTemplatesWithLikesAndUser(),
        builder: (context, snapshot) {
          // 読み込み中はインジケータ表示
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          // エラー表示
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final coverBookId = item['cover_book_id'] as int?;
              final likeCount = item['like_count'] as int? ?? 0;

              // 表紙画像取得
              return FutureBuilder<Map<String, dynamic>?>(
                future: coverBookId != null
                    ? DatabaseHelper.instance.getBookMapById(coverBookId)
                    : Future.value(null),
                builder: (context, coverSnapshot) {
                  String? thumbnailUrl;
                  if (coverSnapshot.connectionState == ConnectionState.done &&
                      coverSnapshot.data != null) {
                    thumbnailUrl =
                        coverSnapshot.data!['thumbnail_url'] as String?;
                  }

                  return ListTile(
                    // 左側にランキング番号またはサムネイル
                    leading: CircleAvatar(
                      backgroundImage:
                          (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                          ? NetworkImage(thumbnailUrl)
                          : null,
                      child: (thumbnailUrl == null || thumbnailUrl.isEmpty)
                          ? Text('${index + 1}')
                          : null,
                    ),
                    // タイトルと作成者
                    title: Text(item['title'] ?? 'タイトルなし'),
                    subtitle: Text(
                      '作成者: ${item['username'] ?? '不明'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    // 右側にいいね数表示
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, color: Colors.pink),
                        const SizedBox(width: 4),
                        Text('$likeCount'),
                      ],
                    ),
                    // タップで教材セット詳細画面へ遷移
                    onTap: () {
                      final bookHash = item['book_hash'] as String?;
                      if (bookHash != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HashBookScreen(
                              bookHash: bookHash,
                              title: item['title'] ?? 'タイトルなし',
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      );
    }

    // ------------------------
    // 「人気レビュー」ランキング（rec_set_id単位のいいね数）
    // ------------------------
    return FutureBuilder<List<Map<String, dynamic>>>(
      // DBからレビュー情報と作成者情報を取得
      future: DatabaseHelper.instance.getBookSetTemplatesWithUser(),
      builder: (context, snapshot) {
        // 読み込み中インジケータ
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        // エラー表示
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];
        final Map<int, Map<String, dynamic>> latestSets = {};

        // 同じ rec_set_id の中で最新のデータを保持
        for (var item in items) {
          final recSetId = item['rec_set_id'] as int;
          final addedAt =
              DateTime.tryParse(item['added_at'] ?? '') ?? DateTime(1970);
          if (!latestSets.containsKey(recSetId)) {
            latestSets[recSetId] = item;
          } else {
            final existingAddedAt =
                DateTime.tryParse(latestSets[recSetId]!['added_at'] ?? '') ??
                DateTime(1970);
            if (addedAt.isAfter(existingAddedAt)) {
              latestSets[recSetId] = item;
            }
          }
        }

        final latestItems = latestSets.values.toList();

        return ListView.separated(
          itemCount: latestItems.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = latestItems[index];
            final recSetId = item['rec_set_id'] as int;
            final coverBookId = item['cover_book_id'] as int?;

            // rec_set_idごとのいいね数取得
            return FutureBuilder<int>(
              future: DatabaseHelper.instance.getLikeCountByRecSetId(recSetId),
              builder: (context, likeSnapshot) {
                debugPrint(
                  '🔹 recSetId=$recSetId  state=${likeSnapshot.connectionState}  data=${likeSnapshot.data}',
                );

                final likeCount = likeSnapshot.data ?? 0;

                // 表紙画像取得
                return FutureBuilder<Map<String, dynamic>?>(
                  future: coverBookId != null
                      ? DatabaseHelper.instance.getBookMapById(coverBookId)
                      : Future.value(null),
                  builder: (context, coverSnapshot) {
                    String? thumbnailUrl;
                    if (coverSnapshot.connectionState == ConnectionState.done &&
                        coverSnapshot.data != null) {
                      thumbnailUrl =
                          coverSnapshot.data!['thumbnail_url'] as String?;
                    }

                    return ListTile(
                      // 左側にランキング番号またはサムネイル
                      leading: CircleAvatar(
                        backgroundImage:
                            (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                            ? NetworkImage(thumbnailUrl)
                            : null,
                        child: (thumbnailUrl == null || thumbnailUrl.isEmpty)
                            ? Text('${index + 1}')
                            : null,
                      ),
                      // タイトルと作成者
                      title: Text(item['title'] ?? 'タイトルなし'),
                      subtitle: Text(
                        '作成者: ${item['username'] ?? '不明'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      // 右側にいいね数表示
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite, color: Colors.pink),
                          const SizedBox(width: 4),
                          Text('$likeCount'),
                        ],
                      ),
                      // タップでレビュー詳細画面へ遷移
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyPicksDetailScreen(
                              recSetId: recSetId,
                              title: item['title'] as String? ?? 'タイトルなし',
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

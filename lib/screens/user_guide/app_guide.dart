//lib/screens/user_guide/app_guide.dart
import 'package:flutter/material.dart';

class APPGuide extends StatelessWidget {
  const APPGuide({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリの使い方'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack ?? () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GuideHeader(),

          SizedBox(height: 24),

          _GuideCard(
            title: '1. 書籍を登録する',
            steps: [
              '画面右下の「＋」ボタンをクリック。',
              '① 書籍名を入力するか、ISBN（書籍番号）を入力する。',
              '② 学校区分と教科区分をプルダウンから選択する。',
              '③ すでに登録されている書籍は登録できません。',
            ],
          ),

          _GuideCard(
            title: '2. 書籍についてのレビューを読む',
            steps: [
              '① 画面左下の「書籍一覧」ボタンをクリック。',
              '② 画面中央部の並び替え・フィルター機能で目的の書籍を探せます。',
              '③ 書籍をクリックすると詳細ページへ移動し、過去のレビューを参照できます。',
            ],
          ),

          _GuideCard(
            title: '3. 書籍についてのレビューを書く',
            steps: [
              '① 書籍詳細ページ下部の「この書籍をレビューする」をクリック。',
              '② 任意の評価を入力してください。',
              '③ 各項目の意図する内容は「評価項目の説明」ページを参照できます。',
            ],
          ),

          _GuideCard(
            title: '4. 購入したい書籍を比較・検討する',
            steps: [
              '① 書籍一覧画面で「比較する」にチェックを入れる。',
              '② 画面下部の「比較検討」ボタンを押す。',
              '③ 比較リスト内の書籍セット全体の評価を確認できます。',
            ],
          ),

          _GuideCard(
            title: '5. 書籍のリストを保存する（マイセット）',
            steps: [
              '① 購入検討でリストを作成。',
              '② 画面右上から「マイセットを保存」。',
              '※ 同じ組み合わせは1ユーザーにつき1回のみ保存可能。',
            ],
          ),

          _GuideCard(
            title: '6. 書籍のリストを公開する',
            steps: ['① 画面下部の「設定ボタン」へ。', '② ユーザー情報・マイセットの公開設定が変更可能。'],
          ),

          _GuideCard(
            title: '7. おすすめの書籍セットを見る',
            steps: [
              '① 画面下部の「おすすめ」ボタンへ。',
              '② 人気レビュータブ：高評価レビューを確認できます。',
              '③ 人気教材セットタブ：組み合わせの人気度を確認できます。',
              '④ どの教材セットが最も人気か知りたいときに便利です。',
            ],
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'このアプリでは、参考書を登録し、比較し、レビューを読み書きできます。',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 8),
        Text(
          '学習目的に合わせた最適な書籍セットを見つけるために、以下の使い方をご活用ください。',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ...steps.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $t',
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

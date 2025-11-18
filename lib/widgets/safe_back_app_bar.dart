import 'package:flutter/material.dart';

/// 共通の「安全な戻る」AppBar
/// - Navigator.pop が可能な場合は pop
/// - そうでない場合は onFallback を呼ぶ（状態切り替え用）
class SafeBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SafeBackAppBar({
    super.key,
    required this.titleText,
    required this.context,
    this.onFallback,
    this.actions,
    this.backgroundColor,
  });

  /// 表示するタイトル
  final String titleText;

  /// BuildContext（Navigator判定に必要）
  final BuildContext context;

  /// Navigator.pop できない場合に呼ばれるコールバック
  final VoidCallback? onFallback;

  /// 追加のアクションボタン
  final List<Widget>? actions;

  /// 背景色（省略可）
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titleText),
      backgroundColor: backgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.of(this.context).canPop()) {
            Navigator.pop(this.context);
          } else {
            onFallback?.call();
          }
        },
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

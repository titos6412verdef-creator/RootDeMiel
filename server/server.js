// server.js

const express = require('express');
const sqlite3 = require('sqlite3').verbose(); // SQLite用
const path = require('path');
const cors = require('cors'); // Flutterからのアクセス用

const app = express();
const PORT = 3000;

// JSON受け渡し対応
app.use(express.json());
app.use(cors());

// DBパス（Flutterアプリと同じパスに合わせる）
const dbPath = path.join(__dirname, '../review_app.db');
const db = new sqlite3.Database(dbPath, sqlite3.OPEN_READWRITE, (err) => {
  if (err) {
    console.error('DB接続エラー:', err.message);
  } else {
    console.log('SQLite DBに接続しました');
  }
});

// --------------------
// 匿名ユーザー情報取得API
// --------------------
// :user_id パラメータがあれば指定IDで取得、なければ username='匿名ラッコ' の1件
app.get('/api/anonymous_user/:user_id?', (req, res) => {
  const userId = req.params.user_id;
  const sql = userId
    ? "SELECT * FROM Users WHERE user_id = ?"
    : "SELECT * FROM Users WHERE username = '匿名ラッコ' LIMIT 1";
  const params = userId ? [userId] : [];

  db.get(sql, params, (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!row) return res.status(404).json({ error: '匿名ユーザーが存在しません' });
    res.json(row);
  });
});

// --------------------
// サーバー起動
// --------------------
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

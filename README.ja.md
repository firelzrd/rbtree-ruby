# rbtree-ruby

🌍 *[English](README.md) | [日本語](README.ja.md)*

Red-Black Tree（赤黒木）データ構造のピュアRuby実装です。挿入、削除、検索操作がO(log n)の時間計算量で実行できる、効率的な順序付きキーバリューストレージを提供します。

## 特徴

- **自己平衡二分探索木**: 赤黒木の性質により最適なパフォーマンスを維持
- **順序付き操作**: 効率的な範囲クエリ、最小/最大値の取得、ソート済みイテレーション
- **複数値サポート**: `MultiRBTree`クラスで同一キーに複数の値を格納可能
- **ピュアRuby**: C拡張不要、あらゆるRuby実装で動作
- **充実したドキュメント**: 使用例付きの包括的なRDocドキュメント

## インストール

Gemfileに以下を追加:

```ruby
gem 'rbtree-ruby'
```

実行:

```bash
bundle install
```

または直接インストール:

```bash
gem install rbtree-ruby
```

## 使い方

### 基本的なRBTree

```ruby
require 'rbtree'

# 空のツリーを作成
tree = RBTree.new

# データで初期化（バルク挿入）
tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
tree = RBTree[[5, 'five'], [4, 'four']]
tree = RBTree.new do # ブロック初期化
  data_source.each { |data| [data.time, data.content] } 
end

# 値の挿入と取得
tree.insert(10, 'ten')
tree[20] = 'twenty'
# バルク挿入
tree.insert({30 => 'thirty', 40 => 'forty'})
puts tree[10]  # => "ten"

# ソート順でイテレーション
tree.each { |key, value| puts "#{key}: #{value}" }
# 出力:
# 1: one
# 2: two
# 3: three
# 10: ten
# 20: twenty

# イテレーション中の変更
# 標準のHashやArrayとは異なり、`safe: true`オプションを指定することで
# イテレーション中に安全にキーの削除や挿入を行うことができます。
tree.each(safe: true) { |k, v| tree.delete(k) if k.even? }
tree.each(reverse: true) { |k, v| puts k }  # reverse_eachと同じ

# 最小値と最大値
tree.min  # => [1, "one"]
tree.max  # => [20, "twenty"]

# 範囲クエリ（Enumeratorを返す、配列には.to_aを使用）
tree.lt(10).to_a   # => [[1, "one"], [2, "two"], [3, "three"]]
tree.gte(10).to_a  # => [[10, "ten"], [20, "twenty"]]
tree.between(2, 10).to_a  # => [[2, "two"], [3, "three"], [10, "ten"]]

# shiftとpop
tree.shift  # => [1, "one"] (最小値を削除)
tree.pop    # => [20, "twenty"] (最大値を削除)

# 削除
tree.delete(3)  # => "three"

# キーの存在確認
tree.has_key?(2)  # => true
tree.size         # => 2
```

### MultiRBTree（重複キー対応）

```ruby
require 'rbtree'

tree = MultiRBTree.new

# 同じキーに複数の値を挿入
tree.insert(1, 'first one')
tree.insert(1, 'second one')
tree.insert(1, 'third one')
tree.insert(2, 'two')

tree.size  # => 4 (キーバリューペアの総数)

# 最初の値を取得
tree.value(1)      # => "first one"
tree[1]          # => "first one"

# キーの全ての値を取得（Enumeratorを返す）
tree.values(1).to_a  # => ["first one", "second one", "third one"]

# 全キーバリューペアをイテレーション
tree.each { |k, v| puts "#{k}: #{v}" }
# 出力:
# 1: first one
# 1: second one
# 1: third one
# 2: two

# 最初の値のみ削除
tree.delete_value(1)  # => "first one"
tree.value(1)         # => "second one"

# キーの全ての値を削除
tree.delete_key(1)      # 残りの値を全て削除
```

### 最近傍キー検索

```ruby
tree = RBTree.new({1 => 'one', 5 => 'five', 10 => 'ten'})

tree.nearest(4)   # => [5, "five"]  (4に最も近いキー)
tree.nearest(7)   # => [5, "five"]  (同距離の場合は小さいキー)
tree.nearest(8)   # => [10, "ten"]
```

### 前後キー検索

ツリーの中で次のキーまたは前のキーを検索します。

```ruby
tree = RBTree.new({1 => 'one', 3 => 'three', 5 => 'five', 7 => 'seven'})

tree.prev(5)   # => [3, "three"]  (5より小さい最大のキー)
tree.succ(5)   # => [7, "seven"]  (5より大きい最小のキー)

# キーが存在しなくても動作
tree.prev(4)   # => [3, "three"]  (4は存在しない、4未満の最大キーを返す)
tree.succ(4)   # => [5, "five"]   (4は存在しない、4より大きい最小キーを返す)

# 境界ではnilを返す
tree.prev(1)   # => nil (1より小さいキーなし)
tree.succ(7)   # => nil (7より大きいキーなし)
```

### 逆順範囲クエリ

範囲クエリは`Enumerator`を返し（配列には`.to_a`を使用）、`:reverse`オプションをサポート:

```ruby
tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})

tree.lt(3).to_a                    # => [[1, "one"], [2, "two"]]
tree.lt(3, reverse: true).to_a     # => [[2, "two"], [1, "one"]]
tree.lt(3).first                   # => [1, "one"] (遅延評価、配列は作成されない)

# 遅延評価
tree.gt(0).lazy.take(2).to_a  # => [[1, "one"], [2, "two"]] (最初の2件のみ計算)
```

### 変換と結合

標準のRubyオブジェクトへの変換や、他のコレクションとの結合も簡単です:

```ruby
tree = RBTree.new({1 => 'one', 2 => 'two'})

# 配列への変換（Enumerable経由）
tree.to_a  # => [[1, "one"], [2, "two"]]

# ハッシュへの変換
tree.to_h  # => {1 => "one", 2 => "two"}

# 他のツリー、ハッシュ、またはEnumerableの結合
other = {3 => 'three'}
tree.merge!(other)
tree.size  # => 3
```

### MultiRBTree 値配列アクセス

複数の値を持つキーで、どの値にアクセスするか選択:

```ruby
tree = MultiRBTree.new
tree.insert(1, 'first')
tree.insert(1, 'second')
tree.insert(1, 'third')

# 最初または最後の値にアクセス
tree.value(1)               # => "first"
tree.value(1, last: true)   # => "third"
tree.first_value(1)         # => "first"
tree.last_value(1)          # => "third"

# どちらの端からも削除可能
tree.delete_first_value(1)      # => "first"
tree.delete_last_value(1)       # => "third"  
tree.value(1)               # => "second"

# min/maxの:lastオプション
tree.insert(2, 'a')
tree.insert(2, 'b')
tree.min                  # => [1, "second"] (最小キーの最初の値)
tree.max(last: true)      # => [2, "b"]      (最大キーの最後の値)
```

## パフォーマンス

主要な操作は**O(log n)**時間で実行:

- `insert(key, value)` - O(log n)
- `delete(key)` - O(log n)
- `value(key)` / `[]` - **O(1)** (内部ハッシュインデックスによる超高速アクセス)
- `has_key?` - **O(1)** (内部ハッシュインデックスによる超高速チェック)
- `min` - **O(1)**
- `max` - O(log n)
- `shift` / `pop` - O(log n)
- `prev` / `succ` - O(log n)、O(1)ハッシュチェック付き

全要素のイテレーションはO(n)時間。

### RBTree vs Hash vs Array

順序付き操作と空間的操作において、RBTreeは単に速いだけでなく、全く異なるクラスの性能を発揮。**50万件**でのベンチマーク:

| 操作 | RBTree | Hash/Array | 高速化 | 理由 |
|-----|--------|------------|-------|-----|
| **最近傍検索** | **O(log n)** | O(n) スキャン | **〜8,600倍高速** | 二分探索 vs 全件スキャン |
| **範囲クエリ** | **O(log n + k)** | O(n) フィルター | **〜540倍高速** | 部分木へ直接ジャンプ vs 全件スキャン |
| **最小値抽出** | **O(log n)** | O(n) 検索 | **〜160倍高速** | 連続的なリバランス vs 全件スキャン |
| **ソート済みイテレーション** | **O(n)** | O(n log n) | **無料** | 常にソート済み vs 明示的な`sort` |
| **キー検索** | **O(1)** | O(1) | **同等** | **ハイブリッドハッシュインデックスにより、Hashと同等のO(1)検索速度を実現** |

### メモリ効率とカスタムアロケータ

RBTreeは内部的な**メモリプール**を使用してノードオブジェクトを再利用します。
- 頻繁な挿入・削除時のGC負荷を大幅に削減します。
- **自動縮小**: デフォルトの `AutoShrinkNodePool` は、現在の使用量に対してプールが大きくなりすぎた場合、自動的に未使用ノードをRubyのGCに解放します。これにより、負荷が変動する長時間実行アプリケーションでのメモリ肥大化を防ぎます。
- **カスタマイズ**: プールの動作をカスタマイズしたり、独自のアロケータを指定することができます:

```ruby
# 自動縮小パラメータのカスタマイズ
pool = RBTree::AutoShrinkNodePool.new(
  history_size: 60,       # 60秒の履歴
  buffer_factor: 1.5,     # 変動幅の50%をバッファとして保持
  reserve_ratio: 0.2      # 常に最大値の20%を予備として保持
)
tree = RBTree.new(node_allocator: pool)
```

### RBTreeを使うべき場面

✅ **RBTreeが適している場合:**
- キー順でのイテレーション
- 高速なmin/max取得
- 範囲クエリ（`between`, `lt`, `gt`, `lte`, `gte`）
- 最近傍キー検索
- 優先度キュー的な動作（キー順でshift/pop）

✅ **Hashが適している場合:**
- 高速なキーバリュー検索のみ（RBTreeも同等に高速！）
- 順序付けが不要

## APIドキュメント

完全なRDocドキュメントを生成:

```bash
rdoc lib/rbtree.rb
```

`doc/index.html`をブラウザで開いてください。

## 開発

リポジトリをチェックアウト後、`bundle install`で依存関係をインストール:

```bash
# RDocドキュメント生成
rake rdoc

# gemのビルド
rake build

# ローカルインストール
rake install
```

## コントリビューション

バグ報告やプルリクエストはGitHubで受け付けています: https://github.com/firelzrd/rbtree-ruby

## ライセンス

[MIT License](https://opensource.org/licenses/MIT)でオープンソースとして公開。

## 作者

Masahito Suzuki (firelzrd@gmail.com)

Copyright © 2026 Masahito Suzuki

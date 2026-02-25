---
name: daily-work-summary
description: >
  Notion上のインラインデータベースに日次作業メモを自動生成する。Git/Linearの実績収集、構造化、ヒアリングによる振り返り、課題の解決アプローチ提案まで一括実行。
  トリガー: 今日の作業をまとめて、日報作成、作業メモ、daily summary、振り返り
argument-hint: "[NotionデータベースURL]"
---

# Daily Work Summary Skill

Notion上のインラインデータベースに今日の作業メモページを作成し、Git/Linearの作業実績を収集・構造化し、ヒアリングを通じて振り返りを完成させる。

## Prerequisites

- Notion MCP Server が有効であること
- Linear MCP Server が有効であること
- Git リポジトリ内で実行すること

## Input

ユーザーから以下の情報を確認する（不明な場合はヒアリング）:

- **Notion データベースURL**（必須）: 作業メモを書き込むインラインデータベースのURL
  - 引数 `$ARGUMENTS` で渡された場合はそれを使用する
- **Git Author**（任意）: コミットをフィルタするgit author名。省略時は `git config user.name` を使用
- **Linear Assignee**（任意）: Linearタスクの担当者。省略時は `me`

## Workflow

### Step 1: Notion Database Discovery and Page Creation

1. `notion-fetch` でデータベースURLにアクセスし、インラインデータベースの `data_source_id` を取得する
   - データベースURLをそのまま渡すとページとして取得される場合がある
   - ページ内の `<database>` タグから `data_source_url` を取得し、`collection://` URLで再度fetchしてスキーマを確認する
2. データベースのスキーマ（プロパティ名、型）を確認する
3. `notion-create-pages` で今日の日付をタイトルにしたページを作成する
   - タイトル形式: `YYYY-MM-DD 作業メモ`
   - `parent: {"data_source_id": "..."}` を使用する
   - 初期コンテンツは空で作成（Step 3で一括書き込み）

### Step 2: Collect Data from Git and Linear (in parallel)

以下を**並列で**実行する:

**Git commits**:
```bash
git log --all \
  --since="YYYY-MM-DDT00:00:00+09:00" \
  --until="YYYY-MM-{DD+1}T00:00:00+09:00" \
  --author="${GIT_AUTHOR}" \
  --format="%h %s (%ai)"
```
- `Merge branch` で始まるマージコミットはリストから除外する

**Linear issues**:
```
list_issues:
  assignee: "me"
  updatedAt: "YYYY-MM-DD"
  orderBy: "updatedAt"
```
- `completedAt` が今日 → 「完了タスク」
- `status` が "In Progress" → 「進行中タスク」

### Step 3: Write Structured Content to Notion

`notion-update-page` の `replace_content` コマンドで以下の構成で書き込む:

```markdown
## Git作業

- `{commit_hash}` {commit_message} ({PR番号があれば})
- ...

## Linear完了タスク

- **{identifier}** {title}（{project名}）
- ...

## Linear進行中タスク

- **{identifier}** {title}（{project名}）
- ...

## サマリー

今日は主にN個の領域で作業を実施:

1. **{領域名}**: {関連する作業の要約}
2. ...

## まとめ

### 今日の成果
- {Gitコミットと完了Linearタスクから要約を3-5点}

### 気づき/学び
- （ヒアリングで記入）

### 課題/ブロッカー
- （ヒアリングで記入）

### 次やるべきこと
- [ ] {進行中タスクから抽出}
- [ ] ...

### 考えておくべきこと
- {進行中タスクや完了タスクの文脈から推測される検討事項}
```

**Grouping rules**:
- Gitコミットのprefix/scopeとLinearタスクのproject名をもとに作業領域をグルーピング
- 同一領域の作業は1つの箇条書きにまとめる
- 進行中タスクは「次やるべきこと」にチェックリスト形式で記載

### Step 4: Hearing (Interactive Q&A)

ページ書き込み後、以下の順番で**1問ずつ**質問する:

**Q1: 気づき/学び**
> 今日の作業の中で、新しく知ったことや「こうすればよかった」と感じたことはありますか？

- 当日のコミット/タスクから具体的な例を3つ程度提示して回答を促す
- 「なし」の場合はスキップ

**Q2: 課題/ブロッカー**
> 現在進行中のタスクや今日の作業で、困っていること・止まっていることはありますか？

- 進行中タスクから想定される課題を例示
- 「なし」の場合はスキップ

**Q3: 次やるべきこと/考えておくべきことの追加・修正**
> 現在リストアップした内容に追加・修正はありますか？

- 現在の「次やるべきこと」「考えておくべきこと」の内容を提示
- 「良い」「OK」等の場合はそのまま確定

ヒアリング完了後、回答内容を `notion-update-page` でページに反映する。

### Step 5: Research Solution Approaches (conditional)

**Step 4で課題/ブロッカーが記入された場合のみ実行する。**

1. **Web research**: 課題に関連するベストプラクティスを `WebSearch` で調査する
   - 日本語・英語の両方で検索（3-5回）
   - 技術的解決策（ハードスキル）とマインドセット・プロセス改善（ソフトスキル）の両面で調査
2. **Categorize**: 調査結果をカテゴリ別に整理する
   - 仕組みで守る（ツール・プロセス）
   - テクニック（具体的な手法）
   - 環境設計（通知・割り込み制御）
   - 考え方（マインドセット・ソフトスキル）
3. **Append to Notion**: `notion-update-page` でページ末尾に「課題への解決アプローチ」セクションを追加
   - 参考資料のURLを必ず記載する

## Notion API Tips

### Page content updates

- `replace_content_range` はマッチング精度の問題で失敗しやすい
- 部分更新が失敗した場合は `replace_content` で全体を再書き込みする
- 全体書き込み前に必ず `notion-fetch` で最新の内容を取得してから更新すること

### Database data_source_id

- データベースURLをそのまま `notion-fetch` に渡すとページとして取得される場合がある
- ページ内の `<database>` タグから `data_source_url` を取得し、`collection://` URLで再度fetchすることでスキーマを確認できる
- ページ作成時は `parent: {"data_source_id": "..."}` を使用する

## Output

- 作成されたNotionページのURL
- 記載内容の要約（セクション別のポイント数）

## Examples

### Basic usage

```
User: /daily-work-summary https://www.notion.so/cyberagent-group/47c31622fcd049c9af04ad6f716d5126

Claude: [Step 1-3を実行し、ページを作成・データ書き込み]
        [Step 4のヒアリングを開始]
```

### With Git author

```
User: /daily-work-summary https://...
      Git authorは msuga0812 でお願いします

Claude: [msuga0812でフィルタしてStep 1-3を実行]
```

### Minimal invocation

```
User: 今日の作業をまとめて

Claude: NotionデータベースのURLを教えてください。
```

## References

- [A Work Log Template for Software Engineers - The Pragmatic Engineer](https://blog.pragmaticengineer.com/work-log-template-for-software-engineers/)
- [KPT テンプレート - NotePM](https://notepm.jp/template/kpt)
- [Context Switching - Atlassian](https://www.atlassian.com/work-management/project-management/context-switching)

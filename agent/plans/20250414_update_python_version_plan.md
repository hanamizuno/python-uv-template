---
prompt: agent/plans/update_python_version.md
---
# Pythonバージョンと依存ライブラリ更新 実行計画

## 概要
Pythonのバージョンを3.12から3.13に更新し、依存ライブラリも最新化します。
Architectモードで計画とドキュメント保存を行い、Codeモードでファイル編集とコマンド実行を行います。

## 実行計画

1.  **ドキュメントの保存 (Architect):** (完了)
    *   最初のユーザーリクエストを `agent/prompts/update_python_version.md` に保存しました。
    *   この実行計画を `agent/plans/update_python_version_plan.md` に保存します。
2.  **Codeモードへの切り替え依頼 (Architect):**
    *   以下の作業をCodeモードで行うよう、ユーザーに切り替えを依頼します。
        *   `.python-version` ファイルの内容を `3.13` に書き換える。
        *   `pyproject.toml` ファイル内の `requires-python` を `>=3.13` に、`tool.pyright.pythonVersion` を `"3.13"` に変更する。
        *   `Dockerfile` ファイル内の `ARG PYTHON_VERSION` を `3.13` に変更する。
        *   `pyproject.toml` の `[dependency-groups].dev` セクションにある各ライブラリについて、最新バージョンを特定し、バージョン指定を更新する。
        *   `uv lock --upgrade` コマンドを実行して `uv.lock` ファイルを更新する。
        *   `docker compose build --no-cache` でDockerイメージを再ビルドする。
        *   `docker compose run --rm app python --version` でPythonバージョンを確認する。
        *   `docker compose run --rm app task test` でテストを実行する。

## フロー図 (Mermaid)

```mermaid
graph TD
    A[開始] --> B(Architect: ドキュメント保存);
    B --> B1[Save Prompt];
    B --> B2[Save Plan];
    B1 --> C(Architect: Codeモードへ切り替え依頼);
    B2 --> C;
    C --> D(Code: ファイル更新);
    D --> D1[Update .python-version];
    D --> D2[Update pyproject.toml (Python version)];
    D --> D3[Update Dockerfile];
    D1 --> E(Code: 依存関係更新);
    D2 --> E;
    D3 --> E;
    E -- 最新バージョン特定 & pyproject.toml更新 --> E1;
    E1 -- uv lock --upgrade --> E2[Update uv.lock];
    E2 --> F(Code: 動作確認);
    F -- docker compose build --> F1[Build Docker Image];
    F1 -- docker compose run python --version --> F2[Check Python Version];
    F2 -- docker compose run task test --> F3[Run Tests];
    F3 --> G[完了];

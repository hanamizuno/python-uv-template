# Dependabot dependency-groups 対応案

## 問題の概要
- DependabotはPEP 735の`[dependency-groups]`をまだサポートしていない
- そのため、Python依存関係の自動更新が動作しない

## 対応案

### オプション1: project.optional-dependenciesへの移行（推奨）

`pyproject.toml`を以下のように変更：

```toml
[project]
name = "python-uv-template"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
requires-python = ">=3.13"
dependencies = []

[project.optional-dependencies]
dev = [
  "pyright>=1.1.399",
  "pytest>=8.3.5",
  "pytest-asyncio>=0.26.0",
  "pytest-cov>=6.1.1",
  "ruff>=0.11.5",
  "taskipy>=1.14.1",
]
```

インストールコマンドの変更：
- 変更前: `uv sync --dev-dependencies`
- 変更後: `uv pip install -e ".[dev]"`

### オプション2: 現状維持
- Dependabotのサポートを待つ
- 手動で`uv lock --upgrade`を定期的に実行

### オプション3: GitHub Actionsで自動化
定期的に依存関係を更新するワークフローを作成：

```yaml
name: Update Dependencies
on:
  schedule:
    - cron: '0 0 * * 1'  # 毎週月曜日
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v6
      - run: uv lock --upgrade
      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          commit-message: "chore: update dependencies"
          title: "Update Python dependencies"
          branch: update-dependencies
```

## 推奨事項
- 短期的には**オプション1**を採用し、Dependabotの恩恵を受ける
- Dependabotが対応したら`[dependency-groups]`に戻す
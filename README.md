# Fourier

<p align="center">
  <img src="assets/icon.png" alt="Fourier" width="256">
</p>

基于 Flutter 的 Folo RSS 聚合阅读客户端，支持 Android 和 macOS。聚焦高密度信息流阅读：同步与整理订阅内容、逐块渲染长文，并用 DeepSeek 完成可配置的翻译、摘要与垃圾拦截判定。

> Fourier 是个人用途的非官方二次开发客户端，不隶属于 Folo、RSSNext 或其运营方，也不代表官方发布版本。

## 主要功能

<p align="center">
<img src="./assets/article.png" alt="article" />
<img src="./assets/filter.png" alt="filter" />
</p>

- **Folo 与时间线** — 浏览器登录、未读 / 全部筛选、最近阅读、长度排序，以及按时间窗口同步云端已读状态
- **订阅源** — Articles / Social Media / Inbox 分组、分类与订阅源筛选和静默订阅源；Android 提供订阅源搜索，macOS 支持添加、编辑与取消订阅
- **文章阅读** — HTML 拆块渲染、目录跳转、Markdown 复制、图片画廊与普通视频、YouTube、Bilibili 播放
- **AI 辅助** — 翻译、摘要和垃圾拦截使用独立配置与后台队列；拦截结果进入审核页，由用户保留或移除
- **阅读工作流** — macOS 支持静默订阅源批量导出与连续撤销 / 重做；两端均支持 JSON 配置迁移和手动检查更新
- **跨平台体验** — Android 移动端导航与手势交互；macOS 分栏、Liquid Glass、右键菜单和快捷键

## 下载

从 [GitHub Releases](https://github.com/X-Ray-git/Fourier/releases) 下载 Android APK 或 macOS arm64 安装包。安装后可在设置页手动检查后续更新。

## 从源码运行

```bash
flutter pub get
flutter run -d macos       # macOS
flutter run -d <device-id> # Android
```

构建发布产物：

```bash
flutter build macos --release
flutter build apk --release
```

## 首次配置

1. 打开应用 → 设置页
2. 通过浏览器登录 Folo；也可手动填写长期 **Session Token**，或导入旧配置
3. 如需翻译、摘要、垃圾拦截与相关文章关系，填写 **DeepSeek API Key**

## 开发

```bash
dart analyze lib test
flutter test --no-pub
```

## 文档

- 工程 Wiki（中文，克隆后双击 `index.html` 即可离线浏览）：[入口](index.html)
- 交接入口：[`AGENT_HANDOFF.md`](AGENT_HANDOFF.md)
- 知识库维护说明：[`docs/agent_handoff/meta/site-guide.html`](docs/agent_handoff/meta/site-guide.html)

## 许可证

Fourier 按照 [`AGPL-3.0-only`](LICENSE) 授权。第三方版权与许可证见
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

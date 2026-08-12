# OneKeep

OneKeep 是面向 iOS 16+ 的轻量训练执行与记录工具，支持 JSON/AI 计划导入、动作视频在线预览、组次重量记录、可靠计时及 TrollStore IPA 云构建。

## 当前状态

项目处于首版开发阶段，当前代码包含：

- SwiftUI iOS 16 应用骨架。
- 今日、计划、记录三个主入口。
- 低调中性灰、无渐变设计系统。
- 基于目标结束时间的训练计时器。
- MP4/HLS 与网页视频源解析基础。
- Core Data 计划持久化、新建计划和日期/每周/隔周规则。
- JSON 计划导入、导出、版本检查和严格校验。
- BYOK 的 OpenAI 兼容接口、Keychain 存储和可编辑 AI 导入预览。
- 热身、普通、间歇、循环和拉伸训练阶段模型。
- GitHub Actions 编译测试和 IPA 打包。

## 本地生成工程

需要 macOS、Xcode 16 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
xcodegen generate
open OneKeep.xcodeproj
```

最低部署目标为 iOS 16.0，默认 Bundle ID 为 `com.onekeep.app`。

## 云构建

- `ios-ci.yml`：Pull Request 和 `main` 分支执行编译与测试。
- `ios-release.yml`：Tag 或手动触发，生成 TrollStore 使用的 IPA Artifact。

## 产品文档

- [产品规划](PRODUCT_PLAN.md)
- [动作库规划](EXERCISE_LIBRARY_PLAN.md)
- [界面规范](UI_GUIDELINES.md)

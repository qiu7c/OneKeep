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
- BYOK 的 OpenAI 兼容接口、DeepSeek/OpenAI/千问/Gemini 预设、远程模型列表、连接测试与 Keychain 存储。
- 本地多轮 AI 计划对话、改善建议、结构化预览和完整字段编辑；使用动作库稳定 ID、名称/别名/英文名分级匹配、歧义候选及人工改选，未识别动作仅在用户最终确认后创建。
- 130 个本地动作条目均已匹配哔哩哔哩专项教学，含八段锦、太极八法五步、24 式简化太极拳、五禽戏、易筋经和六字诀，并配置 8 条分类备用源；支持定期可用性检测、失效自动回退、100 MB 上限封面缓存和用户本地替换链接。MP4/MOV/M4V 直链可下载离线使用；哔哩哔哩网页视频遵循平台播放方式，仅在线播放。
- 进行中训练、计时目标和组进度本地恢复；支持放弃记录、上次重量复用、计时通知、振动及自动休息设置。
- 重量支持公斤/磅切换；本地数据、JSON 与 ZIP 备份统一按公斤保存，切换单位不会改变原始记录。
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

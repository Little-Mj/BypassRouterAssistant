# 旁路由助手架构

## 单向依赖

```text
SwiftUI Views
    ↓ user intents / observed state
AppState (MainActor orchestration)
    ├── NetworkPolicy (pure decisions and validation)
    ├── ProfileRepository (UserDefaults persistence)
    ├── AppLogStore (bounded file logging)
    ├── NetworkReader (read-only system inspection)
    └── NetworkConfigurationService (privileged write boundary)
```

## 约束

- `OperationState` 是互斥状态机，杜绝“正在操作但同时显示成功”等不可能组合。
- `ProfileEditorRoute?` 是唯一编辑呈现源；所有页面只能请求路由，不能各自创建 Sheet。
- 编辑页只通过这条路由关闭一次，避免状态置空与系统 dismiss 同时发生造成重复呈现。
- `NetworkPolicy` 不访问 UI、文件或系统命令，可以用单元测试穷举关键分支。
- `NetworkConfigurationService` 是唯一允许发起管理员授权的代码边界。
- 管理员脚本会再次核对网卡的系统连接编号；授权期间 Wi-Fi 重新关联时直接终止，不写入旧请求。
- `ProfileRepository` 集中执行 SSID 去重、排序和持久化。
- 视图不推导网络业务规则，只渲染 `recommendedAction` 并发送用户意图。
- 视图按概览、配置、日志、主窗口和菜单栏面板分文件，修改一个功能时不需要触碰其他界面。
- 构建脚本每次从空应用包开始组装，防止已删除的源码或资源残留到安装版。

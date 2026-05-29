# frontend-app 页面结构与 iOS 对齐分析

本文档基于 `frontend-app` 当前真实代码结构整理，用于后续 `frontend-ios` 原生页面继续对齐。重点是还原现有 uni-app/Vue 原型的页面拓扑、用户访问顺序、入口层级、视觉状态和 backend-api 行为，不作为开发排期或任务清单。

## 资料来源与边界

主要参考文件：

- `frontend-app/pages.json`
- `frontend-app/App.vue`
- `frontend-app/utils/router.js`
- `frontend-app/components/k-tab-bar/index.vue`
- `frontend-app/store/modules/app.js`
- `frontend-app/store/modules/auth.js`
- `frontend-app/store/modules/bootstrap.js`
- `frontend-app/store/modules/sync.js`
- `frontend-app/api/index.js`
- `frontend-app/api/modules/*.js`
- `frontend-app/pages/**`
- `frontend-app/styles/_variables.scss`
- `frontend-app/styles/_base.scss`
- `frontend-app/styles/_components.scss`
- `frontend-app/styles/_form.scss`

当前确认：`frontend-app` 有 34 个 `pages.json` 注册页面。`pages/index/index.vue` 存在于目录中，但没有注册到 `pages.json`，不应作为当前有效业务入口。`pages/device-scan/index` 在路由中注册，实际文件为 `pages/device-scan/index.nvue`，用于原生扫码。

## 总体页面拓扑

`frontend-app` 没有使用 `pages.json` 的原生 `tabBar` 配置，而是在四个主页面中手动挂载 `k-tab-bar`。当前主 tab 为：

| tab key | 页面 | 说明 |
| --- | --- | --- |
| `home` | `/pages/home/index` | 首页和工具入口聚合页 |
| `chat` | `/pages/chat/index` | 最新对话摘要和聊天记录入口 |
| `device` | `/pages/device/index` | 设备概览、绑定、列表、设置入口 |
| `profile` | `/pages/profile/index` | 用户、订阅、订单、设置和资产入口 |

注意：当前没有独立的“工具”tab。提醒、记账、穿搭、新闻、邮件等工具入口集中在首页的工具卡片中。

路由按访问角色可分为：

| 类型 | 页面 |
| --- | --- |
| 公开页 | `splash`、`language`、`welcome`、`auth` |
| 登录后主 tab | `home`、`chat`、`device`、`profile` |
| 登录后 onboarding/设备绑定 | `invite`、`device-provisioning`、`device-pairing`、`device-scan`、`device-provisioning2`、`device-pairing2` |
| 首页工具业务 | `reminder`、`accounting`、`news`、`outfit`、`mail` 的 list/detail |
| 聊天业务 | `chat-history/index`、`chat-history/detail` |
| 设备业务 | `device-list`、`device-detail` |
| 账户业务 | `subscription`、`order/list`、`order/detail`、`settings`、`settings-language`、`mail-settings` |

`utils/router.js` 安装了 `navigateTo`、`redirectTo`、`reLaunch`、`switchTab` 拦截器。除公开页外，所有 `/pages/**` 内部页面都要求本地 `token` 存在。未登录访问受保护页面时，会 `reLaunch` 到 `/pages/auth/index`，并尽量携带 `redirect` 参数。

## 启动到主界面的访问顺序

App 启动时，`App.vue` 的 `onLaunch` 会先读取安全区，初始化 app store 和 auth store，安装路由守卫。如果本地已有 token，会执行 `authStore.bootstrap({ silent: true })`，然后启动实时同步。

`App.vue` 的 `onShow` 会更新 CSS 安全区变量，并在已登录时执行 `refreshIfStale({ silent: true })` 和 `startRealtimeSync()`，随后对当前路由做一次守卫检查。

首屏由 `/pages/splash/index` 承接。页面展示 Kiio logo、标题、tagline 和 loading dots，延迟约 1800ms 后分流：

1. 已登录：执行 `authStore.bootstrap({ silent: true })`，进入 `/pages/home/index`。
2. 未登录且未完成语言选择：进入 `/pages/language/index`。
3. 未登录且未完成欢迎页：进入 `/pages/welcome/index`。
4. 语言和欢迎都完成但未登录：进入 `/pages/auth/index`。

本地 onboarding 标记：

- `kiio:onboarding:languageDone`
- `kiio:onboarding:welcomeDone`

语言选择页读取 `SUPPORTED_LOCALES`，当前仅有 `en` 和 `zh_CN`。选择语言会立即更新 app locale，点击继续写入 `languageDone`，然后进入欢迎页。

欢迎页是三页 swiper，支持跳过。点击最后一步或跳过都会写入 `welcomeDone`，然后进入登录注册页。

认证页包含四种模式：

| 模式 | 行为 | 主要接口 |
| --- | --- | --- |
| 密码登录 | 邮箱 + 密码，密码优先使用 SM2 公钥加密 | `GET /user/pub-config`、`POST /user/login` |
| 验证码登录 | 邮箱 + 邮件验证码 | `POST /user/emailVerification`、`POST /user/login` |
| 注册 | 邮箱 + 验证码 + 密码 + 当前语言 | `POST /user/register` |
| 找回密码 | 邮箱 + 验证码 + 新密码 | `PUT /user/retrieve-password` |

登录成功后写入 token，强制 bootstrap，然后按 `redirect` 或默认首页进入主界面。注册成功后写入 token 并 bootstrap，但下一页是 `/pages/invite/index`。

邀请页提供两个入口：

- 添加设备：`/pages/device-provisioning/index`
- 先逛逛：`/pages/home/index`

## 主 tab 与主要入口

### Home

首页是工具聚合页，有 logo top bar、卡片/列表视图切换、问候 mood strip，以及五个工具入口：

| 工具 | 页面 | 说明 |
| --- | --- | --- |
| Reminder | `/pages/reminder/list` | 提醒任务 |
| Accounting | `/pages/accounting/list` | 记账账单 |
| Cloth/Outfit | `/pages/outfit/list` | 穿搭记录 |
| News | `/pages/news/list` | 新闻记录 |
| Mail | `/pages/mail/list` | 邮件操作记录 |

卡片视图有 3D 轮播感，列表视图是纵向卡片。视图状态只存在页面内，不持久化。

### Chat

聊天 tab 当前不是实时发送消息的输入页，而是“最新会话预览 + 历史入口”。

页面先从 `chat/latest` 缓存水合，再通过 bootstrap 获取第一个 agent。若存在 agent，则请求最新一条会话，再拉取该会话历史：

- `GET /agent/{agentId}/sessions?page=1&limit=1`
- `GET /agent/{agentId}/chat-history/{sessionId}`

状态：

- `loading`：显示加载态。
- 无 agent：显示设备/智能体缺失空态。
- 有 agent 但无会话：显示聊天空态。
- 有会话：显示 session summary 和消息气泡。

消息类型：

- `chatType === 1`：用户消息，右侧渐变气泡，若 `content` 是 JSON 会取 `content.content`。
- `chatType === 2`：AI 消息，左侧 acrylic 卡片。
- `chatType === 3`：在聊天 tab 中被过滤。

右上角历史按钮进入 `/pages/chat-history/index`，再进入 `/pages/chat-history/detail`。

### Device

设备 tab 是设备主页，核心是 agent 和 bound devices 的聚合概览。数据来自 bootstrap：

- `GET /agent/list`
- `GET /device/bind/{agentId}`
- `GET /admin/dict/data/type/FIRMWARE_TYPE`

页面状态：

- `loading`：加载态。
- 无 agent：空态，引导添加 companion。
- 有 agent：显示主设备 hero、设备数量、最近连接、全部设备、网络、自动升级开关。

主设备按 `lastConnectedAt` 最新排序。最近在线判断阈值为 10 分钟。自动升级调用：

- `PUT /device/update/{deviceId}`，payload `{ autoUpdate: 0 | 1 }`

右上角加号打开 bottom sheet：

- 添加 companion：`/pages/device-provisioning2/index`
- 设备语言：`/pages/settings-language/index?scope=agent&from=device`

设备列表入口：`/pages/device-list/index?agentId=...`。设备详情入口：`/pages/device-detail/index?id=...&agentId=...`。

### Profile

个人中心从 bootstrap 水合用户、公开配置、agents、devices。主要入口：

| 入口 | 页面/行为 |
| --- | --- |
| 设置按钮 | `/pages/settings/index` |
| Kiio Pro banner | `/pages/subscription/index` |
| agents/devices 资产卡 | `/pages/device-list/index` |
| Digital Closet | `/pages/outfit/list` |
| Orders | `/pages/order/list` |
| Account Security | `/pages/settings/index` |
| About | `uni.showModal` 显示 service/version |

用户展示字段主要来自 `userInfo.username`、`id`、`superAdmin`、`status`。公开配置用于服务名和版本号。

## 设备绑定流程

设备绑定有两组页面：

| 场景 | 引导页 | 配对页 | 完成后 |
| --- | --- | --- | --- |
| 注册后的 invite 流程 | `device-provisioning` | `device-pairing` | 回首页 |
| 已登录后从设备页添加 | `device-provisioning2` | `device-pairing2` | 回设备 tab |

两组页面业务基本一致，差异主要是导航外观、返回行为、文案 key 和完成后的 tab。

配网页说明用户连接设备热点，并提供两个快速动作：

- 打开系统 Wi-Fi 设置。App-Plus Android 使用 `Settings.ACTION_WIFI_SETTINGS`，iOS 使用 `App-Prefs:root=WIFI`。
- 打开或复制设备配置门户：`http://192.168.4.1`。

配对页提供扫码和手动输入 6 位码：

- 扫码页 `/pages/device-scan/index` 是 nvue，使用原生 `barcode` 组件。
- 扫码成功后从结果文本中提取第一个 6 位数字，震动、展示成功卡片，并通过上一页 `$vm.onScanResult(code)` 回填。
- 手动输入使用 6 个视觉 code box + 一个透明真实 input。
- 绑定接口为 `POST /device/bind/{agentId}/{deviceCode}`。

绑定成功后会 `invalidate('device')` 并异步 `forceRefresh({ silent: true })`，然后 toast 成功，延迟返回主 tab。

待确认：当前扫码页只把 code 回传给上一页，并没有在 query 或全局 store 中保存。如果 iOS 实现扫码绑定，可以直接在 SwiftUI/AVFoundation 回调中把 code 写入绑定 view model。

## 首页工具业务页

五类工具页存在高度一致的列表/详情结构：

- 顶部自定义 nav bar，左侧返回首页或上一级。
- 列表页有横向 filter tabs。
- 列表页支持 `scrolltolower` 分页加载。
- 首屏从本地 cache 水合，再按 TTL 或 sync dirty 判断是否刷新。
- 详情页按 `id` 拉取，并在对应 sync module dirty 时静默刷新。
- 空态、加载态、错误 toast、加载更多、没有更多状态均已实现。

### Reminder

页面：

- `/pages/reminder/list`
- `/pages/reminder/detail`

列表筛选：

- `all`
- `active`
- `done`
- `cancelled`
- `expired`

接口：

- `GET /reminder/tasks`
- `GET /reminder/tasks/{id}`
- `POST /reminder/tasks/{id}/complete`
- `POST /reminder/tasks/{id}/cancel`
- `GET /reminder/tasks/{id}/logs`

详情页显示 hero 状态、提醒内容、重复规则、时区、来源、最后触发时间和通知 logs。只有 `status === active` 时显示完成/取消动作，动作前使用 `uni.showModal` 二次确认。

### Accounting

页面：

- `/pages/accounting/list`
- `/pages/accounting/detail`

列表筛选：

- `all`
- `expense`
- `income`
- `pending_confirm`

接口：

- `GET /accounting/bills`
- `GET /accounting/bills/{id}`
- `POST /accounting/bills/{id}/confirm`
- bootstrap 还会预拉 `GET /accounting/categories`、`GET /accounting/accounts`、`GET /accounting/settings`

详情页显示金额 hero、分类、账户、转账目标账户、发生时间、状态、来源、标签、备注。只有 `status === pending_confirm` 时显示确认按钮。

### News

页面：

- `/pages/news/list`
- `/pages/news/detail`

列表筛选来自：

- `GET /news/categories`

列表数据：

- `GET /news/records`

详情：

- `GET /news/records/{id}`

详情页显示标题、来源、时间、缩略图、summary、snippet、分类/type/tagType/keyword，以及可复制 links。

### Outfit

页面：

- `/pages/outfit/list`
- `/pages/outfit/detail`

列表筛选：

- `all`
- `today`，请求参数 `outfitDate`
- `recent`，请求参数 `startDate` 和 `endDate`，当前取最近 7 天

接口：

- `GET /cloth/outfits`
- `GET /cloth/outfits/{id}`

详情页显示大色块 hero、标题日期、穿搭建议、衣物 items 和可复制 links。

### Mail Operations

页面：

- `/pages/mail/list`
- `/pages/mail/detail`

列表右上角设置按钮进入 `/pages/mail-settings/index`。

列表筛选：

- `all`
- `success`
- `failed`
- `pending_confirm`

接口：

- `GET /mail/operations`
- `GET /mail/operations/{id}`

详情页显示操作类型、状态、accountId、requestId、创建/更新时间、summary、errorMessage、rawText、payloadJson。

## 聊天历史页面

页面：

- `/pages/chat-history/index`
- `/pages/chat-history/detail`

历史列表入口来自 Chat tab。若没有传 `agentId`，会用 `getDefaultAgent()` 取第一个 agent。

接口：

- `GET /agent/list`
- `GET /agent/{agentId}/sessions`
- `GET /agent/{agentId}/chat-history/{sessionId}`

列表按今天、昨天、更早分组。详情页复用聊天气泡样式，并滚动到最后一条可见消息。当前没有编辑、删除、继续对话入口。

## 设备列表与详情

页面：

- `/pages/device-list/index`
- `/pages/device-detail/index`

设备列表：

- 从 bootstrap 水合 agents、devices、firmwareTypes。
- 未传 `agentId` 时默认第一个 agent。
- 顶部加号菜单可添加设备或切换排序。
- 排序支持最近连接和名称。
- 按 10 分钟最近在线阈值分为 online/offline。
- 点击设备进入详情。

设备详情：

- 从 bootstrap 中查找 `deviceId`，支持按 `id` 或 `macAddress` 匹配。
- 显示 hero、模型、固件、自动 OTA、最近连接、基础信息、设置项和危险区。
- 设置项包括重命名、自动 OTA、重新配网、刷新状态。
- 重命名与自动 OTA 使用 `PUT /device/update/{deviceId}`。
- 解绑使用 `POST /device/unbind`，payload `{ deviceId }`。
- 重新配网进入 `/pages/device-provisioning2/index?deviceId=...&agentId=...`。

待确认：`device-provisioning2` 接收了 `deviceId` query 的可能性，但当前页面只保存 `agentId`，没有消费 `deviceId`。如果 iOS 要支持“为某台设备重新配网”，需要确认 backend/device 固件侧是否需要 deviceId。

## 设置、语言与邮箱账号

### Settings

页面：`/pages/settings/index`

设置页从 bootstrap 获取用户和偏好。当前可见区块：

- Account：昵称。
- General：App language。
- Notifications & Privacy：push、privacy、security。
- Support：help、agreement。
- Logout。

已确认行为：

- 昵称弹窗只更新页面本地 `nickname`，没有调用 backend 保存。
- Push toggle 当前为空函数。
- Privacy、Security、Help、Agreement 有 cell 样式，但没有跳转逻辑。
- Logout 调用 `authStore.logout()`，清 token/cache/sync 后 `reLaunch` 到 auth。

### Settings Language

页面：`/pages/settings-language/index`

支持两种 scope：

- `scope=app`：保存 `language`，成功后同步更新本地 app locale。
- `scope=agent`：保存 `agentLanguage`，通常从 Device tab 进入。

接口：

- `GET /user/preference`
- `PUT /user/preference`

保存后会 `invalidate('user')` 并后台 `forceRefresh({ silent: true })`。

### Mail Settings

页面：`/pages/mail-settings/index`

用于管理邮箱账号，不是邮件操作记录页。能力包括：

- 查看账号列表和默认账号。
- 新增邮箱账号。
- 编辑邮箱账号。
- 启用/禁用账号。
- 设置默认账号。
- 删除账号。

接口：

- `GET /mail/accounts`
- `POST /mail/accounts`
- `PUT /mail/accounts/{id}`
- `POST /mail/accounts/{id}/default`
- `DELETE /mail/accounts/{id}`

表单字段包括 `email`、`authCode`、`imapServer`、`imapPort`、`smtpServer`、`smtpPort`、`enabled`、`isDefault`。编辑时 `authCode` 可为空，表示保留原授权码。

## 订阅与订单

### Subscription

页面：`/pages/subscription/index`

入口来自 Profile 的 Kiio Pro banner。数据来自 bootstrap：

- `GET /subscription/plans`
- `GET /subscription/me`

页面显示：

- Pro hero。
- 当前套餐和订阅状态。
- 语音额度用量进度。
- 根据选中套餐权益生成 feature list。
- 月付/年付切换。
- plan cards。
- 底部订阅按钮。

订阅行为：

1. `POST /subscription/orders`，payload `{ planCode, billingCycle, channel: 'manual' }`
2. `POST /subscription/orders/{idOrOrderNo}/pay`
3. 清理 subscription bootstrap 数据并重新加载。
4. 进入订单详情。

待确认：当前 uni-app 使用 `manual` 渠道和 backend `pay` 模拟支付。iOS 若走 App Store 内购，需要和此流程区分。

### Order List / Detail

页面：

- `/pages/order/list`
- `/pages/order/detail`

订单列表筛选：

- `all`
- `paid`
- `pending`
- `closed`

接口：

- `GET /subscription/orders`
- `GET /subscription/orders/{idOrOrderNo}`
- `POST /subscription/orders/{idOrOrderNo}/pay`

详情页显示订单状态 banner、商品信息、订单信息、价格明细。若 `status === pending`，底部显示完成支付按钮。

## 数据、缓存与实时同步

### API 包装

`api/index.js` 统一处理请求：

- `BASE_URL = VITE_API_BASE_URL || http://127.0.0.1:8002/xiaozhi`
- 默认 `Content-Type: application/json`
- 非 `ignoreAuth` 请求会从本地 `token` 取 `Authorization: Bearer ...`
- HTTP 非 2xx 会 reject。401 会清认证并跳 auth，保留当前 route 作为 redirect。
- body `code !== 0` 会使用 `msg` toast。
- 网络失败使用全局 network error toast。
- 支持 `dedupeKey` 去重同一请求。

### Bootstrap Store

登录后核心数据集中由 `store/modules/bootstrap.js` 管理：

| 数据 | 接口 | TTL |
| --- | --- | --- |
| userInfo | `GET /user/info` | 10 分钟 |
| preference | `GET /user/preference` | 10 分钟 |
| publicConfig | `GET /user/pub-config` | 6 小时 |
| subscription | `GET /subscription/me` | 5 分钟 |
| plans | `GET /subscription/plans` | 6 小时 |
| agents | `GET /agent/list` | 2 分钟 |
| devices | `GET /device/bind/{agentId}` | 2 分钟 |
| firmwareTypes | `GET /admin/dict/data/type/FIRMWARE_TYPE` | 6 小时 |
| mailAccounts | `GET /mail/accounts` | 5 分钟 |
| accounting meta | `GET /accounting/categories`、`GET /accounting/accounts`、`GET /accounting/settings` | 10 分钟 |

Bootstrap 会先 `hydrate()` 本地缓存，再根据 TTL 或 `force` 决定请求。多处页面依赖 bootstrap 的同一份 agents/devices/user/preference/subscription/plans，因此 iOS 对齐时应避免每个页面独立重复建状态。

### Cache

缓存 key 前缀为 `kiio:v1`，scope 优先使用 `kiio:currentUserId`，其次 token 内的 `userId`，否则 `guest`。

列表页常见缓存域：

- `tool-list:reminder`
- `tool-list:accounting`
- `tool-list:news`
- `tool-list:outfit`
- `tool-list:mail`
- `chat:latest`
- `chat:sessions`
- `chat:history`
- `orders:list`
- `mail:accounts`

### Notify / Sync

登录后 `notify-client.js` 连接：

- WebSocket URL：由 API base 推导到 `/notify/ws?accessToken=...`
- 心跳：25 秒发送 `PING`
- 断线指数退避重连，最大 30 秒
- 收到 `DATA_CHANGED` 后交给 `syncStore.handleDataChanged`

当前 sync module 映射：

| module | 对应缓存 |
| --- | --- |
| `ACCOUNTING_BILL` | `tool-list/accounting` |
| `REMINDER_TASK` | `tool-list/reminder` |
| `NEWS_RECORD` | `tool-list/news` |
| `CLOTH_OUTFIT` | `tool-list/outfit` |
| `MAIL_OPERATION` | `tool-list/mail` |

工具列表和详情页会订阅对应 module。收到 dirty 后，列表静默刷新，详情页若 event `bizId` 匹配当前 id 则刷新。

## 视觉与布局风格

整体风格是轻暖背景、低饱和木色 accent、玻璃拟态和小半径圆角组合。

关键 token：

- 背景：`#FAFAF8`
- 主文字：`#1A1A1A`
- 次级文字：`#8a8a8a`
- muted：`#b0b0b0`
- accent：`#A89880`
- accent light：`#EDE8E1`
- 成功：`#34C759`
- 警告：`#FF9500`
- 错误：`#FF3B30`
- 信息：`#007AFF`

排版：

- 页面主体字体：`Geist`, `-apple-system`, `PingFang SC`, `Microsoft YaHei`, sans-serif。
- 品牌和部分大标题使用 `Newsreader`, Georgia, serif，常见 28px/32px，部分 Profile 用户名为 italic。
- 多数业务页标题使用 15px 到 18px，列表标题 15px 到 16px。

布局规则：

- 几乎所有页面 `navigationStyle: custom`，自己处理顶部安全区。
- 主 tab 页面底部预留 `64px + safe-bottom`，tab bar fixed。
- 二级页一般顶部 nav bar + scroll-view 内容。
- 列表页常用 20px 水平 padding。
- 卡片多为 14px 到 22px 圆角。
- glass/acrylic 卡片常用 `rgba(255,255,255,0.6~0.8)`、`backdrop-filter: blur(16~28px)`、白色边框、轻阴影。
- 状态页通常居中，图标容器 58px 或 72px。

通用组件：

- `k-icon`
- `k-logo`
- `k-button`
- `k-panel`
- `k-cell`
- `k-modal`
- `k-tab-bar`

状态表现：

- loading：旋转圆环或 splash dots。
- empty：浅 accent 背景图标 + title/desc。
- pagination：`loadingMore` 和 `noMore` 文本。
- disabled：降低 opacity 或灰底。
- destructive：`#C0604A` 或红色系。
- online/offline：绿色状态点或灰点，设备在线按最近 10 分钟判断。

## iOS 对齐时最需要稳定保留的行为参考

1. 首次进入顺序应以 `splash -> language -> welcome -> auth -> home/invite` 为准，不要直接从 auth 或 home 起步。
2. 登录后的主 tab 顺序是 Home、Chat、Device、Profile。工具入口属于 Home，不是独立 tab。
3. 所有非公开页面都需要 token 保护。401 后应清登录态并回 auth，同时尽量保留原目标路由。
4. 注册成功后先进入 Invite，而普通登录成功后进入 redirect 或 Home。
5. Chat 当前以历史查看为主，没有前端发送消息输入框。
6. Device 默认取第一个 agent，很多页面还没有多 agent 选择器。
7. 工具列表和详情页应复用“缓存水合、分页、空/加载/更多、sync dirty 静默刷新”的一致模式。
8. Settings 里多个 cell 只是视觉入口，未绑定实际页面或接口，不应在 iOS 中误认为已闭环。
9. Subscription 当前是 backend manual pay 流，不等同于 iOS App Store purchase。
10. 邮件有两个不同业务：`mail/list` 是邮件操作记录，`mail-settings` 是邮箱账号管理。

## 待确认项

- `pages.json` 当前注册标题可正常按 UTF-8 读取；实际页面标题仍主要走页面代码和 i18n key。iOS 应以页面代码和 locale 文案为准。
- `device-provisioning2` 接收 `deviceId` 的入口存在，但页面未消费该参数。重新配网是否需要设备 id 待确认。
- 扫码结果格式当前只提取任意 6 位数字。真实二维码是否可能包含 URL、JSON 或更多字段待确认。
- Settings 的昵称保存、push、privacy、security、help、agreement 尚未接 backend 或二级页。
- 多 agent 选择、agent 切换、agent 详情当前没有成型页面。
- Reminder、Accounting、News、Outfit、Mail 的创建/编辑能力没有在当前页面体系中提供，主要展示由后端/MCP/智能体生成的结果。
- Subscription 的支付渠道在 frontend-app 中固定为 `manual`，iOS 内购闭环需另行确认。
- `mail-settings` 的 `authCode` 存储和展示策略需要确认安全要求。
- Notify 当前只映射工具模块，设备、订阅、聊天、profile 的实时更新仍主要依赖 bootstrap TTL 或页面主动刷新。

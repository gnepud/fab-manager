# 其他功能与集成

## 项目

| ID · 用例 | 标签 | automatable | 前置条件 | 步骤 | 预期 | 历史问题 / 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| PRJ-01 · 发布、检索、编辑与 STL | smoke | 是 | 已登录且允许发布的会员；自制无敏感内容 STL；项目启用 | 从 `/projects/new` 建立项目并附 STL；发布后在 `/projects` 搜索完整关键词；用 slug 的编辑入口保存；删除副本后重搜 | 可上传允许的文件，搜索更新且无 500；编辑无 404；已删项目不再列出（历史首次测试被搜索故障阻塞） | [#17](https://github.com/gnepud/fab-manager/pull/17)、[#22](https://github.com/gnepud/fab-manager/pull/22)、[#23](https://github.com/gnepud/fab-manager/pull/23)、[#28](https://github.com/gnepud/fab-manager/pull/28) |
| PRJ-02 · 协作邀请与私有资料 | full | 是 | 作者和邀请对象各一人；一个私有资料 | 发邀请；在接受前后分别查看可操作的项目；比较公开项目的作者署名 | 未接受不能编辑；接受后按协作权限操作；私有作者仍显示名字但无失效链接 | [#24](https://github.com/gnepud/fab-manager/pull/24)、[#57](https://github.com/gnepud/fab-manager/pull/57) |
| PRJ-03 · 项目资料、分类和格式设置 | full | 是 | 管理员，有使用 Licence 的项目、多个主题/组件/类别/状态 | 在 `/admin/projects` 新建、筛选、改名并删除测试分类资源和 Licence；保存 CAO 扩展/MIME 移除并刷新；检查项目页和导出 | 页面继续可读，不保留已删除 Licence；格式移除持久化且禁止的格式拒绝；Markdown/筛选 ZIP 可下载 | [#71](https://github.com/gnepud/fab-manager/pull/71)、[#73](https://github.com/gnepud/fab-manager/pull/73) |
| PRJ-04 · 举报与项目列表 | full | 是 | 两个会员、管理员、MailCatcher；有多页项目 | 登录举报一个项目；后台关闭或删除举报；筛选并继续加载图库；切换 DoDoc 设置后刷新 | 后台见举报并可处理，邮件送达；无重复卡片；本地 DoDoc 设置持久，不请求验证远端服务 | 无；举报通知缺少链接是待确认产品选择 |

## 自定义、公共页面与新手引导

| ID · 用例 | 标签 | automatable | 前置条件 | 步骤 | 预期 | 历史问题 / 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| CFG-01 · 设置、隐私、文件错误和群组表单 | full | 是 | 管理员、本地站点，启用法语；有测试条款文件及不支持格式样本 | 在 `/admin/settings` 设置并清空隐私追踪值，查看隐私政策、公开页；上传不支持的条款文件；在隐藏停用群组时新增后取消 | 清空值持久；公开页呈现已保存内容；一次错误只显示一条可读提示；取消后无临时群组行 | [#16](https://github.com/gnepud/fab-manager/pull/16)、[#19](https://github.com/gnepud/fab-manager/pull/19)、[#44](https://github.com/gnepud/fab-manager/pull/44)、[#70](https://github.com/gnepud/fab-manager/pull/70) |
| TOUR-01 · 管理引导入口、定位与重放 | full | 是 | 管理员/经理；开启 tour，显示模式 session；新浏览器上下文；法语 | 登录后走 Home；从 Help 打开机器、培训、日历、项目和活动引导；另直接打开引导支持的页面；在新会话重登 | 经理可启动 Home；步骤跟随筛选和正确标签，不冻结；文字翻译；session 模式新会话重播 | [#81](https://github.com/gnepud/fab-manager/pull/81)、[#84](https://github.com/gnepud/fab-manager/pull/84)、[#89](https://github.com/gnepud/fab-manager/pull/89)、[#91](https://github.com/gnepud/fab-manager/pull/91)、[#104](https://github.com/gnepud/fab-manager/pull/104)、[#116](https://github.com/gnepud/fab-manager/pull/116)、[#122](https://github.com/gnepud/fab-manager/pull/122)、[#134](https://github.com/gnepud/fab-manager/pull/134) |
| TOUR-02 · 窄屏引导和管理页 | full | 否 | 手机大小视口，管理员；另用平板视口检查会员页 | 启动 Welcome tour；切换管理标签；打开 Pricing、Members 检查 New plan 与 Import | 引导跳过隐藏步骤，弹窗在视口内；管理标签可达，按钮不溢出 | [#131](https://github.com/gnepud/fab-manager/pull/131)、[#136](https://github.com/gnepud/fab-manager/pull/136)、[#138](https://github.com/gnepud/fab-manager/pull/138)、[#139](https://github.com/gnepud/fab-manager/pull/139)、[#140](https://github.com/gnepud/fab-manager/pull/140) |
| LNG-01 · 已支持语言的页面和错误 | full | 是 | 逐个切换 de/es/it/pt/no/zh-CN；重启 Rails 和前端；有会员和管理员 | 在登录、看板、商店、活动、项目与设置等页抽查；查看选择框、日期货币与近期错误；用 `/api/translations/:locale/app.public` 切换请求语种 | 支持语言不显示原始键，日期货币按语言格式；翻译 API 按请求返回对应语言；区分缺译回退与运行故障 | [#82](https://github.com/gnepud/fab-manager/pull/82)、[#109](https://github.com/gnepud/fab-manager/pull/109)（Crowdin 键，不表示新增已支持语言） |

## 邮件和定时任务

| ID · 用例 | 标签 | automatable | 前置条件 | 步骤 | 预期 | 历史问题 / 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| JOB-01 · 提醒与订阅到期 | full | 是 | MailCatcher；一笔多时段预约已取消较早段；正常和免费延期订阅分别将到期/已到期 | 在隔离库触发对应 worker，核对应用通知及邮件；点击到期邮件续订链接 | 预约提醒只提有效时段；提前七天及到期提醒以实际结束日为准；续订链接到 Plans 且翻译正确 | [#40](https://github.com/gnepud/fab-manager/pull/40)、[#47](https://github.com/gnepud/fab-manager/pull/47)、[#48](https://github.com/gnepud/fab-manager/pull/48)、[#69](https://github.com/gnepud/fab-manager/pull/69) |
| JOB-02 · 组变更、关账提醒与邮件失败 | full | 是 | 会员有旧组证明但缺新组证明；会计期临近；MailCatcher 和可控邮件失败 | 转组后触发证明及关账提醒；从后台查看通知偏好和归档；模拟邮件发送失败 | 旧证明不压制新组提醒；有对应关账提醒；失败不标记为已发送 | [#46](https://github.com/gnepud/fab-manager/pull/46)、[#113](https://github.com/gnepud/fab-manager/pull/113) |

## 认证与 Open API

| ID · 用例 | 标签 | automatable | 前置条件 | 步骤 | 预期 | 历史问题 / 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| AUTH-01 · 合成 SSO 与恢复本地登录 | full | 是 | 独立实例与本地合成 OAuth2、OIDC、SAML IdP；备份原认证设置；本地账号 | 管理员建立提供方和字段映射，分别激活并重启登录，补完资料；SAML 拒绝后尝试正常重登；恢复 FabManager 登录；检查非管理员导航 | 资料与提供方身份关联；拒绝后为可重试的登录页而非 500；恢复后本地登录成功，提供方列表只对管理员开放 | [#72](https://github.com/gnepud/fab-manager/pull/72)、[#83](https://github.com/gnepud/fab-manager/pull/83) |
| API-01 · 本地客户端生命周期 | full | 是 | 管理员；两个仅可访问合成数据的客户端；凭证只保留在当前进程 | 在 `/open_api_clients` 新建、改名、查看文档；用测试 token 读 `GET /open_api/v1/users`；排序后撤销选中的客户端，再比较旧和替代 token | 正常授权返回 200；撤销正确对象，旧 token 401，替代 token 200；不输出 token | [#18](https://github.com/gnepud/fab-manager/pull/18) |

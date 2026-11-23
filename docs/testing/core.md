# 核心业务

入口如 `/dashboard/reservations` 由 [前端路由](../../app/frontend/src/javascript/router.js) 的父子路径组成。以下各组从独立基线开始。

## 账户、会员管理与权限

| ID · 用例 | 标签 | automatable | 前置条件 | 步骤 | 预期 | 历史问题 / 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| ACC-01 · 本地注册及邮件确认 | smoke | 是 | FabManager 本地认证；开放注册；MailCatcher；新的测试邮箱 | 从登录界面注册并提交；打开本地确认邮件再登录；关闭公开注册后重新打开登录界面 | 可收件、确认并登录；关闭后不再显示注册链接 | [#12](https://github.com/gnepud/fab-manager/pull/12) |
| ACC-02 · 密码重置和过期链接 | full | 是 | 本地会员；MailCatcher；分别准备有效与过期链接 | 从忘记密码流程申请链接；提交弱密码，再提交有效新密码；另打开过期链接 | 弱密码提示可读且没有重复冒号；有效链接成功，旧密码失效；无效或过期链接提示可读，不出现 500 | [#79](https://github.com/gnepud/fab-manager/pull/79)、[#107](https://github.com/gnepud/fab-manager/pull/107) |
| ACC-03 · 删除账户约束 | full | 是 | 会员 A 有未来预约，会员 B 有有效订阅；QA Delete 两者皆无；每种状态独立 | 尝试注销三个测试账户；刷新后复核账户与关联记录 | 前两次以当前语言报错且保留账户；无阻塞条件的对照可删除 | [#115](https://github.com/gnepud/fab-manager/pull/115) |
| ADM-01 · 会员导出、标签与头像 | smoke | 是 | 管理员；会员、测试标签与小图片；Sidekiq | `/admin/members` 导出 XLSX 并下载；编辑会员保存标签、更换头像并刷新 | XLSX 可打开；标签保存有已翻译提示；头像持久显示 | [#4](https://github.com/gnepud/fab-manager/pull/4)、[#7](https://github.com/gnepud/fab-manager/pull/7)、[#10](https://github.com/gnepud/fab-manager/pull/10) |
| ADM-02 · 续订、免费延期与随后取消 | full | 是 | 管理员；新购且可续订的套餐；MailCatcher | 从会员编辑页续订，再不刷新取消该订阅；用另一个副本免费延期，比较邮件与页面日期 | 取消的是当前订阅，发票清单更新；延期日期一致且邮件仅在记录可读后发送 | [#6](https://github.com/gnepud/fab-manager/pull/6)、[#14](https://github.com/gnepud/fab-manager/pull/14)、[#15](https://github.com/gnepud/fab-manager/pull/15) |
| ADM-03 · 管理员/经理新增与角色编辑 | full | 是 | 管理员和经理分别登录；干净测试邮箱以及已用邮箱 | 用管理员新建管理员/经理并编辑测试用户角色；重用邮箱；用经理检查普通会员编辑与受限管理入口 | 合法角色操作成功；重复邮箱提示可读；经理可编辑普通会员且额度加载无裸 403，不能删除会员、改角色或编辑其他后台账号 | [#35](https://github.com/gnepud/fab-manager/pull/35)、[#56](https://github.com/gnepud/fab-manager/pull/56)、[#86](https://github.com/gnepud/fab-manager/pull/86)、[#92](https://github.com/gnepud/fab-manager/pull/92) |
| ADM-04 · 会员导入正常与坏行 | full | 是 | 管理员；`/admin/members/import`；以页面模板生成合成 CSV，含 UTF-8 BOM、日期和空单元格 | 确认说明列出 username；上传创建/更新行；按邮箱匹配；查看结果；另上传未知标签/培训、坏日期、坏格式或被拒绝的文件 | 保留匹配会员 ID 和空值对应的原数据；坏行明确报告，不清空生日、卡住任务或让结果页崩溃；文件拒绝有提示 | [#99](https://github.com/gnepud/fab-manager/pull/99)、[#100](https://github.com/gnepud/fab-manager/pull/100)、[#101](https://github.com/gnepud/fab-manager/pull/101)、[#102](https://github.com/gnepud/fab-manager/pull/102)、[#119](https://github.com/gnepud/fab-manager/pull/119)、[#121](https://github.com/gnepud/fab-manager/pull/121)、[#123](https://github.com/gnepud/fab-manager/pull/123)、[#126](https://github.com/gnepud/fab-manager/pull/126)、[#127](https://github.com/gnepud/fab-manager/pull/127) |
| ADM-05 · 角色导航与数据隔离 | full | 是 | 管理员、经理、合作伙伴、两个合成会员；设置一个私有资料 | 分角色检查会员列表、导入和管理菜单；以第二会员检查可访问的发票、钱包与预约；合作伙伴搜索该会员 | 普通会员只见自己的交易；经理不具备导入、设置与会计结账权限；合作伙伴搜索不暴露私有资料 | [#38](https://github.com/gnepud/fab-manager/pull/38)、[#68](https://github.com/gnepud/fab-manager/pull/68)、[#124](https://github.com/gnepud/fab-manager/pull/124) |

## 看板、家庭与证明

| ID · 用例 | 标签 | automatable | 前置条件 | 步骤 | 预期 | 历史问题 / 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| DASH-01 · 看板和公开资料 | smoke | 是 | 有发布项目、订单、训练/预约记录的会员 | 刷新 `/dashboard/reservations`；查看资料和项目作者标记；在订单和预付包筛选中检查占位文字；关闭商店再回看板 | 刷新不留空白；作者标记与选择提示为当前语言；私有作者无死链接；商店关闭后无 Orders 标签；预约清单并非取消入口 | [#36](https://github.com/gnepud/fab-manager/pull/36)、[#42](https://github.com/gnepud/fab-manager/pull/42)、[#43](https://github.com/gnepud/fab-manager/pull/43)、[#57](https://github.com/gnepud/fab-manager/pull/57)、[#64](https://github.com/gnepud/fab-manager/pull/64) |
| DASH-02 · 资料编辑 | full | 是 | 本地认证，会员账户；合法新邮箱 | 打开 `/dashboard/profile` 更新邮箱并刷新，退出后重新登录 | 资料持久化；该配置下改邮件地址不会触发重新确认（`reconfirmable = false`） | 无 |
| FAM-01 · 家庭设置、儿童及证明 | full | 是 | 管理员；会员；MailCatcher；一份无个人信息的测试 PDF；启用家庭和验证设置 | 点击设置标签切换开关；设立 Child/User 文件类型并关联组；添加儿童、上传并替换儿童和成人 PDF、更新儿童电话、下载 PDF；对照输入刚满 18 岁和小一天的出生日期；后台按儿童全名搜索 | 标签可切换对应开关；授权双方可读 PDF；变更与邮件匹配；刚满 18 岁不可作为儿童添加，未满可添加；可通过儿童姓名找到父母，未验证筛选只针对成人账户 | [#39](https://github.com/gnepud/fab-manager/pull/39) |
| FAM-02 · 拒绝证明不重复发送 | full | 是 | 未验证会员，已上传必需文件；管理员；MailCatcher | 进入会员 Supporting documents；选择文件类型并填写说明，提交拒绝；不刷新，重开对话框 | 空白表单不能发送；只收到本次提交的会员邮件和管理员副本 | [#51](https://github.com/gnepud/fab-manager/pull/51) |
| FAM-03 · 验证后订家庭活动 | full | 是 | 家庭活动 8 个空位；两个未验证儿童；活动要求验证；另设 €5 活动并充值钱包 | 查看未验证成人和已上传证明但未验证儿童各自的阻拦；管理员批准后购买 1 张儿童票；重开同场选择器；用 1 个空位另测满员与数量上限；在付费场次以钱包结账 | 验证前有提示且不能确认；批准后扣 1 个名额；已报名儿童不可重复选择；最后一位售出后显示满员；付费场次实扣 €5，有预约及发票邮件 | 无 |
| FAM-04 · 零票和已删除儿童 | full | 是 | 免费家庭活动；有子女的会员；另有与子女关联的活动报名 | 点 Book，票数 1 改 0 且无参与者；另删除可删除的儿童并查看其旧报名 | 无法确认零票且不生成预约；名单不继续显示已删除儿童姓名 | [#58](https://github.com/gnepud/fab-manager/pull/58)、[#108](https://github.com/gnepud/fab-manager/pull/108) |

## 日历、预订、活动与培训

| ID · 用例 | 标签 | automatable | 前置条件 | 步骤 | 预期 | 历史问题 / 修复 |
| --- | --- | --- | --- | --- | --- | --- |
| CAL-01 · 日历、XLSX 与培训标题 | smoke | 是 | 会员有培训预约；管理员；Sidekiq | 查看 `/calendar` 的已约培训；从 `/admin/calendar` 导出可用时段，下载并打开文件 | 标题无多余撇号；后台生成 XLSX 而不是在当前页显示原始导出 JSON | [#4](https://github.com/gnepud/fab-manager/pull/4)、[#20](https://github.com/gnepud/fab-manager/pull/20) |
| CAL-02 · iCalendar 来源和同步 | full | 是 | 管理员；本地可控 iCal 服务；Sidekiq/调度器 | 在 `/admin/calendar/icalendar` 增加源；顺序提供初始事件、更新、503、合法空 feed，最后删除源 | 事件可辨读；更新刷新数据；503 不抹掉事件；合法空 feed 与删除会清除该源事件（历史空 feed 最终状态只核对了数据库） | [#45](https://github.com/gnepud/fab-manager/pull/45)；文字颜色见[日历报告](https://app.devin.ai/attachments/76777d56-40f3-4b1e-af43-0f57a84f1f6f/calendar-qa-report.md)，未匹配 PR |
| BOOK-01 · 登录后继续预约，机器取消不退钱包 | smoke | 是 | 开放机器、空间、培训各有未来时段；会员钱包；启用取消 | 游客从空间/培训的 reserve 页面登录；再用钱包预约开放机器；记账后取消 | 登录返回原预约页面；机器预约成功，取消释放时段但不退款；记录取消状态 | [#8](https://github.com/gnepud/fab-manager/pull/8)、[#118](https://github.com/gnepud/fab-manager/pull/118)（管理员取消邮件署名） |
| BOOK-02 · 截止、窗口与套餐限额 | full | 是 | 站点含 DST 的时区；启用预约/取消期限；分别配置套餐机器、分类与其他适用限额 | 比较会员与后台在截止前后表现；测试取消关闭、空、0 与边界；尝试保存开启不早于关闭的窗口；对比本地午夜前后预约和 DST 窗口 | 有效窗口正确裁剪；错误窗口不保存；按本地日计算限额，适用的后台豁免正常 | [#50](https://github.com/gnepud/fab-manager/pull/50)、[#74](https://github.com/gnepud/fab-manager/pull/74) |
| BOOK-03 · 移动、重叠与锁定时段 | full | 是 | 会员已有预约；开放防重叠；可用、满员、过去及锁定时段 | 从管理界面尝试移动到目标时段；以会员尝试部分重叠的活动或锁定时段；取消冲突方后重测 | 满员、过去和非本资源时段不可移动到；锁定和未取消的重叠时段不可预订；已取消不计冲突 | [#53](https://github.com/gnepud/fab-manager/pull/53)、[#75](https://github.com/gnepud/fab-manager/pull/75)、[#76](https://github.com/gnepud/fab-manager/pull/76)、[#88](https://github.com/gnepud/fab-manager/pull/88) |
| BOOK-04 · 后台代订、切换顾客与赠送 | full | 是 | 管理员/经理；不同费率的两个会员；训练未授权会员；可预订机器 | 在机器 reserve 页用旧版会员选择器选顾客并加时段，检查第二顾客自己的金额；用旧版购物车开关赠送时段；以经理查看可选目标 | 按当前顾客计价，赠送只作用在选中顾客；管理员/经理可替未培训会员代订，经理不能替管理员/经理订 | [#110](https://github.com/gnepud/fab-manager/pull/110)、[#117](https://github.com/gnepud/fab-manager/pull/117)（新版购物车 API 有单独回归，当前机器页未启用该面板）、[#125](https://github.com/gnepud/fab-manager/pull/125) |
| EVT-01 · 活动创建、票种、改订与取消 | full | 是 | 管理员、会员；有标准与优惠价、限额和开放报名的活动 | 从 `/admin/events` 创建并编辑活动；会员预报名并支付；后台查看名单和混合票种改订，再取消或删除活动 | 已付款预报名显示已付款；改订正确保留票种；不虚报满员；取消记录不再出现在会员即将举行的活动里 | [#25](https://github.com/gnepud/fab-manager/pull/25)、[#26](https://github.com/gnepud/fab-manager/pull/26)、[#27](https://github.com/gnepud/fab-manager/pull/27)、[#33](https://github.com/gnepud/fab-manager/pull/33) |
| TRN-01 · 授权、撤销与批量验证 | smoke | 是 | 受 QA Training 限制的机器，未授权会员，有已到场的培训预约 | 分别用管理员、经理在会员页授权/撤销；从培训监控提交批量验证并重复操作 | 授权可预约机器，撤销后受限；同一培训无重复授权或通知 | [#92](https://github.com/gnepud/fab-manager/pull/92)、[#103](https://github.com/gnepud/fab-manager/pull/103) |
| TRN-02 · 自动取消：实付与额度 | full | 是 | 低于阈值的培训；实付钱包、百分比/固定额优惠和订阅额度场景；MailCatcher；受限机器 | 记录实付/额度，运行 `TrainingAutoCancelWorker`；查看凭证、钱包、通知、额度及机器预约界面 | 实付退款与实际扣款相等，不多退 0.01；额度支付不退钱包、不生成退款凭证、不恢复额度；会员收到正确邮件且取消培训不再显示待完成 | [#80](https://github.com/gnepud/fab-manager/pull/80)、[#87](https://github.com/gnepud/fab-manager/pull/87)、[#106](https://github.com/gnepud/fab-manager/pull/106)、[#129](https://github.com/gnepud/fab-manager/pull/129) |
| TRN-03 · 授权失效与儿童满龄通知 | full | 是 | 已培训会员和即将满 18 岁儿童；邮件；本地时钟可控 | 用 `TrainingAuthorizationWorker` 验证到期、手动撤销；巴黎午夜后对已满龄儿童运行 `ChildAgeWorker` | 预约权限取消，邮件使用真实培训日期；满龄通知按本地日期发送，展示 18 岁生日而非出生日期 | [#77](https://github.com/gnepud/fab-manager/pull/77)、[#78](https://github.com/gnepud/fab-manager/pull/78)、[#90](https://github.com/gnepud/fab-manager/pull/90) |

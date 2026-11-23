# 覆盖边界

本页以三轮后的 `untested-features.md` 为基线，并以第 4 轮记录及合并 PR 去重；“未测”不表示该功能错误或当前可用。已取得证据的部分在前面各区域，不在这里重复计数。

## 无法用本地基线验证

- **OpenLab** 联邦和真实远程 DoDoc：只检查本地设置，不连接外部实例。
- **reCAPTCHA**：无真实站点端到端配置；不把本地登录成功当验证。
- **真实 SSO**：仅合成 OAuth2/OIDC/SAML；真实 IdP、生产变体、现有账户合并/关联及 `send_code` 不在覆盖中。
- **真实 SMTP**：使用 MailCatcher 或 Rails 测试收件箱，不验证生产投递。
- **真实 PayZen 后续扣款**：此前测试计划的一期实际到账曾观察到；第二/三期的成功与拒绝只验证本地 mock 对账，未观察真实沙箱后续扣款。换卡跨账户隔离只做离线测试；过期购物车提示以模拟 422 验证，而非真实陈旧购物车。
- **不受支持的语言**：`zh` 不等于 `zh-CN`，`sv` 未启用；历史有原始键/5xx，部分支持语种仍有英文回退。不纳入受支持语种通过标准。

## 尚待补测

| 区域 | 未验证或未完成 |
| --- | --- |
| 日历 | 内部事件显示、创建后改标签/套餐、删除“此项及之后”、到场付款、每周首日；空 iCal feed 最终状态仅查数据库。 |
| 活动 | 银行卡结账（含付费家庭活动，已测钱包）、修改后会员邮件、循环活动“之后全部”；早期无成功改订记录，混合票种改订用例依据修复 PR。 |
| 订阅与预付包 | 实时 Stripe 订阅/分期、更换 Stripe 卡、并发/重复提交和重复扣款对账、续订后再次使用额度、预付包刷卡、空间包编辑器（历史未找到）；零元分期仍显示等待支票需确认。 |
| 商店 | 店面分页、并发末件、隐藏商店后直接 URL 的产品口径；同一行按金额/数量部分退款、反向库存原因的接口矩阵、分类排列全组合及所有修复合并后的重跑。历史窄屏修复只覆盖涉及入口，不代表完整移动端覆盖。 |
| 邮件与任务 | 真实到期日、会计关闭、证明、培训/儿童年龄 cron 边界；对应 worker 手动触发与真实调度不可互换。隐私政策更新通知的完整送达链证据不足。 |
| 项目 | 匿名举报（当前要求登录）、并发插入分页；偶发 React 表单错误未重现；举报通知是否要链接待确认。 |
| 外部订阅源 / 运维 | `/ical/reservations/:reservable_type` 与 RSS 活动源；版本检查、告警、`/health`、`/admin/sidekiq`。日历管理的 iCal 导入与会员订阅源是不同功能。 |
| Open API | 除 `GET /users` 外的 plans、plan_categories、prices、trainings、user_trainings、reservations、machines、spaces、bookable_machines、invoices、events、availabilities、accounting、subscriptions；文档返回时短暂登录界面未能稳定重现。 |
| 引导、翻译及扩展角色场景 | 未逐页验证各语种、浏览器中的 3DS 失败文案、完整移动端布局；早期仅以 API/测试验证的分支不应标为已在浏览器验证。 |

## 来源与置信度

- 原始分区记录：团队 QA 记忆 `files/browser-test/`（各区 JSON、`round3-map.json`、`round4-map.json`、`untested-features.md`）；`fab-manager-qa.md` 与 `fab-manager.md` 提供环境及业务口径。
- [第 3 轮汇总](https://app.devin.ai/attachments/68a5a016-334b-4b1b-87bf-fa3b823ecbb1/fab-manager-browser-test-round3.md)、[第 4 轮报告](https://app.devin.ai/attachments/80a620b1-d7dc-433e-abde-5f40818eee0e/fab-manager-round4-report.md) 与 [合并 SWF PR](https://github.com/gnepud/fab-manager/pulls?q=is%3Apr+is%3Amerged+SWF+in%3Atitle)。第 4 轮报告直连返回 401；该轮细节取自记忆记录和可核实 PR，不能确认报告中未另存的观察项。第 4 轮地图中的任务编号只标记范围，不代表已通过。
- 第 2 轮仅商店、项目、活动、日历留有逐区记录；对机器/分类、空间、培训、套餐/分类、定价、价格分类/年龄段、设置、发票、优惠券、群组不推断完整 CRUD 覆盖。第 3 轮发票/会计、钱包/优惠券和自定义/公共页主要依靠汇总与修复 PR，不将其推断为每个正常流程都曾完整执行。
- 合并 PR 描述中有的验证是 API、测试夹具或 MailCatcher，而非修复后浏览器复跑。这里的表是**未来回归的预期标准**，不是本次浏览器执行结果。

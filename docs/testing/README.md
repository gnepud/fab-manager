# Fab-manager 浏览器回归测试手册

| 区域 | 用例 |
| --- | --- |
| 账户、会员与权限；家庭与证明；看板；日历、预订、活动与培训 | [核心业务](core.md) |
| 订阅与预付包；发票、会计与统计；商店；Stripe 与 PayZen TEST | [交易与报表](commerce.md) |
| 项目；设置与公共页面；新手引导；翻译；邮件与任务；SSO 与 Open API | [其他功能与集成](platform.md) |
| 本轮不可验证、待补测和无法确认的范围 | [覆盖边界](coverage-gaps.md) |

## 开始之前

1. 记录被测提交、浏览器与视口、应用语言、站点时区和网关。默认以法语界面运行；路径中的 `:id`、`:slug` 从本次创建的数据中选取，不依赖数据库 ID。下文金额示例为 EUR。
2. 使用**一次性本地开发库**、隔离的 Redis 与 Elasticsearch；不要连生产或导入真实会员。参见 [开发环境说明](../../doc/development_readme.md)；确保 Rails 与前端构建已就绪。启动 Sidekiq 处理 PDF、导出及异步邮件；生产 SMTP 用 MailCatcher 替代。
3. 按下节初始化。每组测试使用新的独立浏览器上下文（管理员、经理、会员各一个），以免共享登录。会改变余额、库存、可用时段或删除数据的用例应从相同的基线恢复再跑，不能按上一用例的余量猜测。
4. 先跑 `smoke`；完整回归再跑 `full`。表中的 `automatable`「是」表示可写为 Playwright/Rails system test（必要时由 Rails 夹具准备数据或触发 worker）；「否」表示本手册仍依赖人工、外部沙箱或视觉检查，不等于功能不可测。
5. 记录每条用例的提交、角色、输入、观察值与 Pass / Fail / Blocked。链接指向历史发现对应的合并 SWF PR；没有匹配的已知修复写「无」或附原始报告，不把当时的结果当成当前提交的通过证明。

## 初始化数据

在本地开发配置中填写环境变量（只用测试值，不截图、不提交）：`ADMIN_EMAIL`、`ADMIN_PASSWORD`、`BROWSER_QA_PASSWORD`。密码须符合应用规则：12–128 字符、大小写字母、数字及特殊字符。使用项目正常的 Postgres、Redis 和 ES 配置；从仓库根目录执行：

~~~sh
RAILS_ENV=development SKIP_TEST_DATABASE=1 bundle exec rails db:create db:schema:load db:migrate db:seed
RAILS_ENV=development bundle exec rails fablab:es:build_stats
RAILS_ENV=development bundle exec rails runner docs/testing/seed_browser_qa.rb
~~~

`db:schema:load` 只用于首次准备空库，`db:migrate` 补上 schema 尚未包含的迁移。runner 要求关闭在线支付，会启用空间及商店，不会重置余额、库存、密码或已经用过的预约。可用时段按执行日之后的日期创建；同一天重跑不会重复创建基线记录。需要重复消费、支付、删除或跨日验证时，使用新的库或恢复预先保存的本地快照。

| 数据 | 用途 |
| --- | --- |
| `qa-admin@example.com`、`qa-manager@example.com` | 管理员、经理；初始密码来自 `BROWSER_QA_PASSWORD` |
| `qa-member@example.com`、`qa-member2@example.com`、`qa-other@example.com` | 两个同组会员及一个不同费率的跨组会员；初始密码同上 |
| `qa-partner@example.com`、`qa-delete@example.com` | 合作伙伴；可删除会员的干净对照 |
| `QA Browser`、`QA Browser Other` | 主会员组及跨组对照 |
| `QA Machine`、`QA Open Machine`、`QA Training`、`QA Space` | 有培训限制/无培训限制机器、培训、空间和未来空档 |
| `QA Plan`、`QA Machine` 的预付包 | 订阅、额度和机器时长；分期、优惠券、已消费额度按用例在 UI 配置 |
| `QA Standard Event`、`QA Family Event`、`QA Product`、`QA Browser Project` | 付费标准活动、免费家庭活动、测试商品库存、已发布项目 |

报名、授权培训、上传证明文件、充值、买套餐、创建发票、取消、导入、开关配置都按具体用例重做。需用钱包时，管理员在 `/admin/members/:id/edit` 的 `Porte-monnaie` 给测试会员充值，并在操作前记录余额；混合支付用例只充值一部分。需要特定日期、名额或限额时，在该用例的独立数据副本中调整。

外部网关默认不要连接；Stripe 只在另起的本地测试实例绑定 `STRIPE_API_KEY`、`STRIPE_PUBLISHABLE_KEY`，并在 Admin 配置对应 TEST 设置、同步测试对象。PayZen 只在独立实例配置 `PAYZEN_TEST_USERNAME`、`PAYZEN_TEST_PASSWORD`、`PAYZEN_TEST_ENDPOINT`、`PAYZEN_TEST_PUBLIC_KEY`、`PAYZEN_TEST_HMAC`、`PAYZEN_TEST_CURRENCY`（这些是供本地传值的名称，不是应用自动读取的变量）；绝不登记真实卡或将 token/密钥写进日志。邮件账号如需配置，仅从 `SMTP_USER_NAME`、`SMTP_PASSWORD` 取值，本地默认不需要。

## 业务口径

- 普通机器预约取消**不退钱包**；不要把培训自动取消时的退款规则套用到机器。
- `Avoir`（credit note）是**会计凭证**；开具凭证不是向银行、支付网关或钱包发起退款。商店取消/退款不自动补库存。
- 账户有未来预约或有效订阅时**不得删除**，并显示已翻译的错误。
- 培训自动取消**不恢复订阅培训额度**；免费/额度支付没有钱包款可退。
- 管理员和经理**代会员预订**时不受培训前置条件限制；会员给自己预订仍受限。

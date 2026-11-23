# Fab-manager browser test guide

[Version française](../fr/testing/README.md)

| Area | Test cases |
| --- | --- |
| Accounts, members, permissions, dashboard, family, calendar, reservations, events, and training | [Core functions](core.md) |
| Subscriptions, prepaid packs, invoices, accounting, statistics, store, and payment sandboxes | [Commerce and reports](commerce.md) |
| Projects, settings, public pages, tours, languages, email, jobs, SSO, and Open API | [Platform and integrations](platform.md) |
| Limits and external services | [Coverage limits](coverage-gaps.md) |

## Prepare a test run

1. Record the app commit, browser, viewport, app language, site time zone, and payment gateway.
2. Select English for the English cases. Text in quotation marks is an exact app label. Use routes to identify pages where no label is given. Get each `:id` or `:slug` from the test data. The example amounts use EUR.
3. Use an isolated, disposable development database, Redis, and Elasticsearch. Do not connect to production. Do not import real member data. See the [development environment guide](../development_readme.md).
4. Start the Rails app and the front end. Start Sidekiq for PDFs, exports, and email jobs. Use MailCatcher in place of production SMTP.
5. Load the data below. Restore the same initial state before each case that changes balances, stock, slots, or records. Use a separate browser context for each role.
6. Run the `smoke` cases first. Add the `full` cases for a full regression run. **Automatable: Yes** identifies a Playwright or Rails system test candidate. Use Rails fixtures or run a worker to prepare conditions when necessary. **No** means this procedure needs manual action, an external sandbox, or a visual check.
7. Use the case ID in the automated test name. Set up the preconditions. Turn the expected results into assertions. Record the role, inputs, and observed result. Record Pass, Fail, or Blocked. If a service or test record is missing, record the reason for Blocked.

## Load test data

Set `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and `BROWSER_QA_PASSWORD` in the local development environment. Use test values only. Do not capture or commit the values. Use passwords of 12 to 128 characters with an uppercase letter, a lowercase letter, a digit, and a special character.

Use the project's PostgreSQL, Redis, and Elasticsearch configuration. Run these commands from the repository root:

~~~sh
RAILS_ENV=development SKIP_TEST_DATABASE=1 bundle exec rails db:create db:schema:load db:migrate db:seed
RAILS_ENV=development bundle exec rails fablab:es:build_stats
RAILS_ENV=development bundle exec rails runner doc/testing/seed_browser_qa.rb
~~~

Run `db:schema:load` only on an empty database. Run `db:migrate` to apply migrations not in the schema. Disable online payment before you run the script. The script enables spaces and makes the store visible to members. It creates future slots and indexes them after commit. A second run on the same day does not duplicate the initial records. It does not reset balances, stock, passwords, or reservations. For cases that consume or delete data, and for tests across dates, use a fresh database or restore a local snapshot.

| Test data | Purpose |
| --- | --- |
| `qa-admin@example.com`, `qa-manager@example.com` | Administrator and manager |
| `qa-member@example.com`, `qa-member2@example.com`, `qa-other@example.com` | Two members in one group and one member in a group with different rates |
| `qa-partner@example.com`, `qa-delete@example.com` | Partner and a member account that the app can delete |
| `QA Browser`, `QA Browser Other` | Main and comparison member groups |
| `QA Machine`, `QA Open Machine`, `QA Training`, `QA Space` | Machine with a training requirement, machine without one, training, and space, with future slots |
| `QA Plan`, prepaid pack for `QA Machine` | Subscription, credits, and prepaid machine time |
| `QA Standard Event`, `QA Family Event`, `QA Product`, `QA Browser Project` | Paid standard event, free family event, product with stock, and published project |

All test accounts use `BROWSER_QA_PASSWORD` at creation. Create any additional data in the isolated copy for each case. For wallet payments, sign in as administrator. Open `/admin/members/:id/edit`. Add funds on the “Wallet” tab. Record the balance before payment. Add only part of the amount for mixed payments.

Keep external gateways off by default. For Stripe, use a separate local TEST instance. Supply `STRIPE_API_KEY` and `STRIPE_PUBLISHABLE_KEY`. Configure the TEST settings and sync the test objects. For PayZen, use a separate local TEST instance. Supply values for setup with `PAYZEN_TEST_USERNAME`, `PAYZEN_TEST_PASSWORD`, `PAYZEN_TEST_ENDPOINT`, `PAYZEN_TEST_PUBLIC_KEY`, `PAYZEN_TEST_HMAC`, and `PAYZEN_TEST_CURRENCY`. The app does not read these PayZen variable names automatically. Do not use real cards. Do not log tokens or keys. If a test mail account requires credentials, use `SMTP_USER_NAME` and `SMTP_PASSWORD`. MailCatcher does not need them for the default setup.

## Business rules

- A standard machine reservation cancellation does not refund the wallet. The training auto-cancellation rule is different.
- A credit note is an accounting document. It does not send a refund to the bank, the gateway, or the wallet. Store cancellation or refund does not add stock.
- The app must block account deletion if there is a future reservation or an active subscription. It must show an error in the selected language.
- Automatic training cancellation does not return subscription training credits. Free or credit-only payments have no wallet amount to refund.
- Administrators and managers can book for members without training approval. Members who book for themselves still need approval when the machine requires it.

## Check exact UI labels

From the repository root, run `ruby doc/testing/check_ui_labels.rb`. Put exact English UI labels in curly double quotes. Use backticks for routes, identifiers, and test data. The check compares quoted labels in both guides with values in the corresponding app locale files. Use the page's translation key when you add or change a label. A matching value alone does not prove that it appears on that page.

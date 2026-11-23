# Coverage limits

These limits are not pass or fail criteria. If a case needs a service that is not available, record the case as Blocked.

## Not available in the local baseline

- **OpenLab and remote DoDoc:** Check only the local settings. Do not connect to a remote instance.
- **reCAPTCHA:** Local sign-in does not test a real site integration.
- **SSO:** Use only synthetic OAuth2, OIDC, and SAML providers. Real identity providers, production variants, linking or merging existing accounts, and `send_code` are out of scope.
- **SMTP:** Use MailCatcher or the Rails test inbox. This does not test production delivery.
- **Later PayZen payments:** Use a local mock to test reconciliation. It does not test real later charges, cross-account card changes at the gateway, or real expired carts. A simulated HTTP 422 tests only how the page handles the error.
- **Unsupported languages:** Do not treat `zh` as `zh-CN`. The app does not enable `sv`. Do not assert coverage for unsupported languages. For supported languages, distinguish an English fallback from a runtime error.

## Scenarios outside these cases

| Area | Scenarios |
| --- | --- |
| Calendar | Display internal events. Change tags or plans after creation. Delete one occurrence and all later ones. Change the first day of the week. |
| Events | Pay by card, including paid family events. Send email to members after a change. Change all later occurrences of a recurring event. |
| Subscriptions and prepaid packs | Stripe subscriptions and payment schedules in a real integration. Stripe card changes. Concurrent or repeated submissions and duplicate charge reconciliation. Reuse credits after renewal. Buy a pack by card. Edit a space pack. Check the payment status for a zero-amount schedule. |
| Store | Browse pages of products. Buy the last item concurrently. Refund part of one order line by amount or quantity. Test all order status and stock reason combinations through the API. Test all category sort combinations. |
| Email and jobs | Verify the scheduler at actual expiry, accounting closure, document, training, and child-age boundaries. Running a worker manually does not test scheduling. Test production delivery of privacy policy updates. |
| Projects | Report a project without sign-in (the app requires sign-in). Insert a project during pagination. Check the project link in the report notification. |
| External feeds and operations | Test `/ical/reservations/:reservable_type` and the RSS event feed. These are not the calendar import. Test version checks, alerts, `/health`, and `/admin/sidekiq`. |
| Open API | Test endpoints other than `GET /users`: `plans`, `plan_categories`, `prices`, `trainings`, `user_trainings`, `reservations`, `machines`, `spaces`, `bookable_machines`, `invoices`, `events`, `availabilities`, `accounting`, and `subscriptions`. Test navigation from the API documentation back to the app. |
| Administration | Test all create, view, update, and delete operations for machines and categories, spaces, trainings, plans and categories, pricing, price categories and age ranges, settings, invoices, coupons, and groups. |
| Tours, languages, and mobile layout | Check every page in each supported language. Check 3DS failure text in each language. Check the full mobile layout. |

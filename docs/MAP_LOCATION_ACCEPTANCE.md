# Map & Location Release Acceptance

Record the tester, build commit, device/browser, and result for every item. Do
not paste API keys, full search queries, or precise coordinates into the report.

## Android device

- [ ] A restricted Android Maps key renders the Trip Map and Place Picker.
- [ ] `Use my location` asks for foreground permission only after it is tapped.
- [ ] Temporary denial can be retried; permanent denial opens App settings.
- [ ] Disabled location services offer Location settings.
- [ ] A fresh location replaces an older emulator/device reading.
- [ ] Accuracy is shown; a value over 200 m warns but remains confirmable.
- [ ] Dragging the pin clears the GPS accuracy label and reverse geocodes again.
- [ ] More than 20 distinct locations cluster; tapping a cluster zooms in.
- [ ] Day 1, Day 2, and All preserve the expected markers and connectors.

## iOS device

- [ ] A bundle-restricted iOS Maps key renders both map surfaces.
- [ ] Only When In Use permission is requested; no Always permission appears.
- [ ] Permission, disabled-service, freshness, accuracy, pin, and cluster flows
      behave as on Android.

## Web

- [ ] Localhost and the production HTTPS origin can request browser location.
- [ ] An insecure non-local HTTP origin shows the secure-origin explanation.
- [ ] The Web Maps key works only for approved HTTP referrers.
- [ ] Search, reverse geocoding, day connectors, clustering, and previews work.

## Failure and privacy checks

- [ ] A missing rendering key shows the navigable location-list fallback.
- [ ] A Google timeout/error leaves the previous selection and offers Retry.
- [ ] A rate-limit database failure returns a temporary error without calling
      Google; request 21 in one 60-second user window returns HTTP 429.
- [ ] The map and fallback say lines show journal order, not navigation.
- [ ] Logs contain no server key, full user query, precise coordinate, or user
      profile data.
- [ ] Entry, Health Log, and Meals either all save or all roll back.

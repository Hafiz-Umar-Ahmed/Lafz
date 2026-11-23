# Lafz: Software Requirements Specification

Nov 19, 2026 · @Kung FU

This SRS specifies how Lafz is built as a single scope on Flutter with native widget, wallpaper and Shortcuts integrations and a minimal, optional backend.

## 1. Scope, constraints and assumptions

This SRS covers the single Lafz release described in the PRD: one scope, one backlog, built in milestones M0 to M8. Requirement IDs (FR, NFR, CON, AD) support tests and backlog tracking. Priority is **Core** (works offline with no account) or **Layer** (optional service, behind a feature flag).

| ID | Constraint or assumption |
| --- | --- |
| CON-01 | The core app needs no account and no network after first launch. Accounts exist only for sync and submissions. |
| CON-02 | Rotation timing is not exact. The OS controls background work and widget refresh. |
| CON-03 | iOS wallpaper automation depends on Shortcuts behavior and is gated by M0. |
| CON-04 | Only administrator-approved content is distributed. The app never executes content received from a server. |
| CON-05 | Minimum OS versions are fixed at the end of M0. Starting assumption: Android 8.0 and iOS 16. |
| CON-06 | No AI-generated quotes or religious content, no automatic translation, no public social features. |
| CON-07 | Backend is a managed service plus static content hosting, not custom servers, to keep operations minimal. |

## 2. Architecture

The app is local-first. Everything a user sees comes from the on-device database; the backend only adds optional services and delivers content packages.

```
DEVICE
  Flutter app: onboarding, library, search, preview, settings
    Application layer (Riverpod): collection filtering, rotation orchestration
    Data layer (Drift/SQLite + FTS5): content, favorites, settings, rotation state
  Native modules
    Android: WorkManager, WallpaperManager, AppWidget, native renderer
    iOS: WidgetKit, App Intents, Shortcuts, App Group storage, native renderer
  Shared layout spec (JSON) used by both native renderers
        |  optional, HTTPS
BACKEND (managed)
  Content CDN: signed, versioned content packages and image assets
  Auth + sync API: backup, sync, entitlement mirror (Layer)
  Submissions API + admin moderation tool (Layer)
  Opt-in analytics endpoint (Layer)
```

| ID | Decision | Reason |
| --- | --- | --- |
| AD-01 | Flutter for shared UI; Kotlin and Swift for platform integrations | One UI codebase, native code where the OS requires it. Plan 40 to 50% of engineering effort for native work. |
| AD-02 | Wallpapers rendered natively from a shared JSON layout spec | A background job cannot reliably render the Flutter UI; the spec keeps both platforms consistent. |
| AD-03 | Rotation logic is a pure, deterministic module with a native port for background workers | Testable alone, runnable without the Flutter engine. |
| AD-04 | Drift over SQLite with FTS5 | Relational content, fast offline search, versioned migrations. |
| AD-05 | Android data in app-private storage; iOS widget data in an App Group container | Widgets and extensions must read what the app writes. |
| AD-06 | Content as signed, versioned packages from a CDN; a baseline package is bundled | Offline first launch plus correction and revocation without an app release. |
| AD-07 | iOS widget timelines are pre-generated for several days | Rotation continues when the app is not running. |
| AD-08 | Entitlements verified with the stores and cached with an expiry | Premium is never a plain local boolean. |
| AD-09 | Sync is last-write-wins per record, with tombstones for deletes | Simple, adequate for favorites, collections and settings. |
| AD-10 | Managed backend (for example Supabase or Firebase) rather than custom servers | Smallest operating burden for a small team; final choice is an open decision. |

## 3. Technology stack

| Area | Choice |
| --- | --- |
| App framework | Flutter, Dart |
| State management | Riverpod |
| Local database | SQLite via Drift, FTS5 search |
| Android background work | WorkManager |
| Android wallpaper and widgets | WallpaperManager; native AppWidget (Glance or RemoteViews) |
| iOS widgets and automation | WidgetKit, App Intents, Shortcuts, Swift |
| Rendering | Native Canvas (Android) and Core Graphics or SwiftUI ImageRenderer (iOS) from a shared JSON spec |
| Content format | JSON packages with manifest, checksum and signature |
| Backend | Managed auth, database and storage; static CDN for packages and images |
| Purchases | StoreKit, Google Play Billing |
| Analytics | Opt-in, minimal event analytics; no quote text, no personal identifiers |
| Testing | flutter\_test, integration\_test, XCTest, Android instrumented tests |
| Content format | Straight JSON quote library bundled in assets, segmented by plan tier (free / premium) |

Project layout: `lib/` with `app`, `core`, `features` (onboarding, library, search, collections, favorites, widgets, wallpapers, automation, sync, community, settings, premium) and `data`; `android/` and `ios/` for native modules.

## 4. Functional requirements

### 4.1 Content and discovery (Core)

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-001 | Browse published categories, subcategories, personalities and quotes | Category to quote navigation works; empty categories show an empty state; unpublished items never listed |
| FR-002 | Search quotes, personalities, sources and categories | Case-insensitive; clearable; 500 ms or less at 10,000 quotes on a mid-range device; Arabic and Urdu queries match exact text |
| FR-003 | Show quotes according to user entitlement tier (free, premium) | Free tier users access curated core wisdom; premium subscribers access the full quote library; content is gathered directly from the bundled quote file |
| FR-004 | Quote detail with text, attribution, source, reference, language, original, translation, plan tier | Clear source attribution and plan tier without complex verification status machinery |

### 4.2 Personalization (Core unless noted)

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-005 | Follow and unfollow categories, subcategories, personalities and curated collections | Persists across restarts; unfollow removes from future rotation; favorites stay available |
| FR-006 | Enable or disable each followed collection per surface | Widget and wallpaper selections are stored separately and never affect each other |
| FR-007 | Favorites | Persist offline; usable as a rotation source; previewable as wallpaper |
| FR-008 | On-device recommended collections | Computed from follows and favorites only; no network call; no generated text |
| FR-009 | Personal collections | Create, rename, delete, add and remove quotes; usable as a rotation source |
| FR-010 | Personal quotes | Private, labeled Personal, never uploaded unless sync is on |
| FR-011 | Creator collections (Layer) | Delivered through content packages; published only by the administrator; creator named and linked |
| FR-012 | Onboarding | Skippable steps; no account; live preview after first choice; defaults valid if skipped |
| FR-013 | Settings persistence | Schedules, collections, appearance and favorites survive restart and OS process death |

### 4.3 Widgets (Core)

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-014 | Widget display of quote and attribution in three layouts, themes and backgrounds | No text overflow at any supported size; readable in light and dark |
| FR-015 | Widget rotation with its own schedule | Intervals per FR-026; state persists; iOS timeline holds at least 7 days of entries and is rewritten on launch and on settings or content change |
| FR-016 | Widget fallback | A bundled quote and open-app prompt appear if no eligible quote exists or data cannot be read |
| FR-017 | Next-quote and open-in-app actions where the platform allows | Tap deep-links to quote detail |

### 4.4 Wallpapers (Core)

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-018 | Render a wallpaper from quote, background, preset and typography | Matches device resolution; text inside safe areas; contrast at least 4.5:1 or overlay applied; saved atomically; 3 s or less |
| FR-019 | 5 to 8 presets with bounded font, alignment, size, overlay and palette options | Every preset passes readability checks on every bundled background |
| FR-020 | Preview with simulated lock-screen and home-screen overlays | Preview matches final render |
| FR-021 | Wallpaper rotation with its own collections, schedule and style | Idempotent per interval slot; only eligible quotes; a failed update leaves the current wallpaper unchanged |

### 4.5 Automation and schedules (Core)

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-022 | Android scheduled wallpaper change for lock, home or both | Unique work per surface; re-enqueued after reboot, update and restart; permission failures give a plain-language message |
| FR-023 | Android automation health | Shows last success; warns when overdue by more than twice the interval; links to battery settings with device-specific steps |
| FR-024 | iOS guided Shortcuts workflow (gated by M0) | App Intent returns a freshly rendered image; guided steps, test action and troubleshooting; copy never claims silent rotation unless validated |
| FR-025 | Wallpaper export on both platforms | One tap saves to Photos or Files at correct lock and home sizes |
| FR-026 | Schedules: 6, 8, 12, 24 hours, specific times, routine presets (morning, study, work, evening, sleep), manual | Time-zone and clock changes recompute from last rotation; never rotates twice per trigger |

### 4.6 Languages and content updates (Core)

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-027 | English, Arabic and Urdu with right-to-left layout | Diacritics render correctly in widgets, wallpapers and UI on tested devices; a language is enabled only after tests pass |
| FR-028 | Signed content updates | Manifest checksum and signature verified; invalid or partial package rejected; last valid package stays; user data untouched; revoked quotes hidden and favorites show a notice |
| FR-029 | Offline operation | Browse, search, favorites, widgets, wallpaper generation and settings work with no network |

### 4.7 Accounts, sync, community and premium (Layer)

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-030 | Optional sign-in with Apple or Google | App is fully usable signed out; sign-in is requested only for sync and submissions |
| FR-031 | Backup and sync of follows, favorites, personal collections, personal quotes and settings | Last-write-wins per record with tombstones; works after offline edits; no quote text from the verified library is uploaded |
| FR-032 | Account deletion | In-app action deletes all server data and confirms completion |
| FR-033 | Quote submission | Requires attribution and source; shows status and rejection reason; rate-limited; never public before approval |
| FR-034 | Moderation tool | Administrator queue to approve, reject, edit and convert a submission into a draft quote that still passes the editorial workflow |
| FR-035 | Report an incorrect quote | Report from quote detail reaches the review queue; reporter is not shown to other users |
| FR-036 | Premium entitlements | Free content stays accessible; status verified with the store, cached with expiry |
| FR-037 | Restore purchases | Available in settings on both platforms |
| FR-038 | Opt-in analytics | Off until the user agrees; events contain no quote text and no personal identifiers; matches store privacy labels |

## 5. Rotation engine and wallpaper rendering

### 5.1 Rotation engine

Each surface (widget, wallpaper) has its own state: enabled, schedule, collections, include-favorites flag, current quote, last and next rotation times, a shuffle bag of quote ids, and the content version it was built on.

**Selection algorithm (shuffle bag):**

1. Build the eligible set: published and displayable quotes in the surface’s enabled collections, plus favorites or personal collections if enabled.
2. If the set is empty, return the bundled fallback quote.
3. Drop ids from the bag that are no longer eligible. If the bag is empty, refill it with the eligible set in random order.
4. Take the next id. If it equals the current quote and alternatives exist, take the one after it.
5. Save the new current quote, timestamps and bag in one transaction.
6. Hand the quote to the renderer or widget.

**Scheduling rules:**

- A rotation is due when now is at or after the next rotation time. After rotating, the next time is now plus the interval, or the next specific time of day for time-based schedules.
- Time-zone or clock changes recompute from the last rotation. A trigger never rotates more than once.
- The idempotency key is surface plus schedule slot; a repeated trigger in the same slot does nothing.
- A content update that removes the current quote forces a rotation at the next check.
- The engine is pure and deterministic for a given random seed, with 90% branch coverage or better in unit tests.

### 5.2 Wallpaper rendering

1. Validate the quote and select the background.
2. Crop to the device’s physical resolution using the image’s stored focal point.
3. Compute the safe text area: reserve the top for the lock-screen clock and widgets, the bottom for gesture areas, and avoid cutouts.
4. Apply a readability overlay when the sampled background contrast is below 4.5:1.
5. Lay out the quote, then attribution and source. Auto-fit by stepping the font size down to a minimum, then truncate with an ellipsis. Text never overflows.
6. Export to a temporary file, check it decodes, then move it into place atomically.
7. Apply it (Android) or expose it to the automation or export action (iOS).

Fonts are bundled. Arabic and Urdu use fonts verified for shaping and diacritics. The layout spec is JSON shared by both native renderers so output is consistent. A small pre-rendered buffer (the next few wallpapers) is kept as a fallback if a background render fails.

## 6. Data model

### 6.1 Device database (SQLite)

| Table | Key fields |
| --- | --- |
| categories | id, name, parent\_id, description, sort\_order, publication\_status, tier |
| personalities | id, name, description, category\_id, image\_path, publication\_status, tier |
| quotes | id, text, attribution, personality\_id, language, source\_title, source\_reference, source\_url, original\_text, original\_language, translation\_source, verification\_status, publication\_status, content\_version, tier |
| quote\_categories | quote\_id, category\_id |
| creator\_collections | id, name, creator, description, tier |
| backgrounds | id, type, file\_path, focal\_x, focal\_y, license, attribution, tier |
| favorites | quote\_id, created\_at, updated\_at, deleted\_at |
| followed\_collections | collection\_id, collection\_type, created\_at, updated\_at, deleted\_at |
| surface\_collections | surface, collection\_id, enabled |
| user\_collections and user\_collection\_items | id, name, quote\_id, order, updated\_at, deleted\_at |
| user\_quotes | id, text, attribution, notes, updated\_at, deleted\_at |
| rotation\_settings | surface, enabled, schedule\_type, interval\_hours, times\_json, routine, include\_favorites, current\_quote\_id, last\_rotation\_at, next\_rotation\_at, shuffle\_bag\_json, content\_version |
| wallpaper\_settings | preset, background\_id, font, alignment, text\_size, overlay, palette, show\_attribution, show\_source, destination |
| content\_meta | installed version, checksum, installed\_at |
| quotes\_fts | FTS5 index over quote text, attribution and source title |

Changes from the earlier draft: explicit publication status instead of a boolean, a separate per-surface collection table, tier flags on content, backgrounds with licence tracking, the shuffle bag, soft-delete columns for sync, and the personal tables.

### 6.2 Backend (managed)

| Collection | Purpose |
| --- | --- |
| users | Account id, sign-in provider, created date; no profile data |
| sync\_records | Per-user records for follows, favorites, personal collections, personal quotes, settings, each with updated\_at and deleted\_at |
| submissions | Submitted quote, attribution, source, submitter id, status, reviewer decision and reason, created date |
| reports | Quote id, reason, created date, status |
| entitlements | Store-verified premium status mirror, expiry |
| content\_releases | Package version, checksum, signature, release notes, published date |

Access rules: each user can read and write only their own sync records and submissions; reports are write-only for users; everything else is administrator-only.

### 6.3 Content record (authoring format)

```
{
  "id": 1,
  "text": "...",
  "attribution": "...",
  "personality_id": 101,
  "category_ids": [1, 10],
  "language": "en",
  "source": { "type": "book|speech|interview|quran|hadith|other",
              "title": "...", "reference": "...", "date": "...", "url": null },
  "islamic": { "surah": null, "ayah": null, "collection": null,
               "hadith_ref": null, "grading": null,
               "arabic": null, "translation_source": null },
  "tier": "free"
}
```

This clean JSON format powers the direct quote file, tagged by plan tier (`free` or `premium`).

## 7. Non-functional requirements

Targets are measured on real devices, not assumed.

| ID | Area | Requirement |
| --- | --- | --- |
| NFR-01 | Performance | Cold launch 3 s or less; library load 2 s or less; local search 500 ms or less at 10,000 quotes; wallpaper render 3 s or less; ordinary interactions 200 ms or less on a representative mid-range device |
| NFR-02 | Performance | App size budget set after asset decisions (starting target under 150 MB with bundled scenery; larger packs downloaded on demand) |
| NFR-03 | Reliability | No loss of favorites, personal quotes or settings in normal use, upgrades or content updates; versioned and tested database migrations from every released version |
| NFR-04 | Reliability | Wallpaper and widget updates fail safely and keep the previous state; scheduled work recovers after reboot, app update and clock changes; no duplicate scheduled tasks |
| NFR-05 | Reliability | Crash-free sessions 99% or more; wallpaper generation success 99% or more |
| NFR-06 | Security | Remote content over HTTPS, checksum and signature verified, schema validated, treated as data only; purchases only through platform stores |
| NFR-07 | Security | Backend access rules enforce per-user isolation; rate limits on submissions and reports; signing keys never stored in the repository |
| NFR-08 | Privacy | No account for core use; sync and submissions collect only what they need; in-app account deletion; analytics opt-in and minimal; store privacy labels match behavior |
| NFR-09 | Accessibility | OS font scaling and screen readers supported; semantic labels on all controls; WCAG 2.1 AA contrast for text; state never shown by color alone |
| NFR-10 | Localization | UI strings externalized; right-to-left layout and Arabic or Urdu typography verified before each language is enabled |
| NFR-11 | Maintainability | Content separate from UI code; platform integrations behind interfaces (WallpaperApplier, WidgetUpdater, Renderer); CI runs static analysis, unit tests and content validation on every change |

## 8. Platform design notes

**Android**

- Use unique periodic work per surface with a flexible window. Expect delays from Doze and manufacturer battery managers; periodic work has a 15-minute minimum and is not exact.
- Apply wallpapers through WallpaperManager with the lock, system or both flags; handle security exceptions and devices that block lock-screen changes.
- Provide a check-my-device screen: battery optimization status, last run time, overdue warning and links to settings.
- Widgets update from a worker and on user action, and stay readable across launcher grid sizes.
- Test matrix: Pixel, Samsung, Xiaomi or Redmi, Oppo or Realme, OnePlus.

**iOS**

- Widgets read pre-generated timelines from the App Group container, so rotation continues without the app running; refresh frequency is system-managed.
- Shortcuts: an App Intent returns the next rendered image and the Shortcut performs the wallpaper action. In M0, record for each tested iOS version: lock versus home targeting, confirmation prompts, Run Immediately behavior, and behavior while the device is locked.
- App Store copy describes Shortcuts and widget use accurately and does not claim capabilities the OS does not provide.
- Purchases through StoreKit; sign in with Apple is offered wherever another sign-in provider is.

## 9. Testing and release acceptance

| Level | Scope |
| --- | --- |
| Unit | Rotation engine, collection filters, content validation, layout and auto-fit logic, sync merge rules |
| Integration | Database migrations, package install and rollback, widget data sharing, sync conflicts, entitlement caching |
| Device | Android OEM matrix; iOS on at least two OS versions, one small and one large iPhone |
| Soak | 7-day scheduled-rotation run on real devices with every rotation logged |
| Accessibility | Screen reader walk-through, large font, contrast checks |
| Languages | Arabic and Urdu rendering and right-to-left layout on real devices |
| Content | Validator passes; 10% manual spot check per content release |
| Security | Backend access rules tested with a second account; signed-package tamper test |
| Beta | 20 to 50 users; measure setup completion, rotation reliability and drop-off |

**Release acceptance:** every requirement in section 4 meets its criteria; the 7-day soak shows rotations on time within OS tolerance on a Pixel and on an aggressive-battery device; the iOS workflow either reaches 80% guided-setup success or ships under the fallback positioning; no known data-loss defect; store privacy labels verified.

## 10. Single backlog and build order

One backlog, built in this order. Each epic ships to testers when its milestone gate passes; there are no version labels.

| Milestone | Epic | Requirements | Gate |
| --- | --- | --- | --- |
| M0 | Feasibility sprint: Android wallpaper, iOS Shortcuts, native widget prototypes | FR-014, FR-015, FR-022, FR-024 (prototype) | Written verdict per integration; minimum OS versions; iOS positioning |
| M1 | Content foundation: quote schema, straight quote library, plan tiers | FR-003, FR-004, FR-028, Section 6 | Straight JSON quote library installs directly into local database |
| M2 | Core app: database, library, search, follow, favorites, onboarding, offline, signed updates | FR-001, FR-002, FR-005 to FR-008, FR-012, FR-013, FR-028, FR-029 | Onboarding under 90 s; revoked quote disappears after update |
| M3 | Rendering and rotation | FR-018 to FR-021, FR-026, Section 5 | Engine tests pass; render 3 s or less |
| M4 | Widgets on both platforms | FR-014 to FR-017 | 7-day widget soak |
| M5 | Automation: Android scheduler and health, iOS Shortcuts or export | FR-022 to FR-025 | 7-day soak on two Android devices; iOS verdict applied |
| M6 | Personal layer and languages | FR-009, FR-010, FR-011, FR-019 (packs), FR-027 | Arabic and Urdu render correctly on devices |
| M7 | Cloud layer: sign-in, sync, submissions, moderation tool, reports, analytics | FR-030 to FR-035, FR-038 | Sync conflict and access-rule tests pass |
| M8 | Premium and launch: purchases, restore, paywall, store preparation, beta | FR-036, FR-037, NFR-01 to NFR-11 | Beta meets PRD metrics; release acceptance in section 10 |

Tier flags (free or premium) are present in the schema from M1 so premium content can be assigned during content work, and feature flags keep every Layer item switchable until its gate passes.

## 11. Review feedback adopted

| Feedback | Where it appears here |
| --- | --- |
| Native integrations are most of the work | AD-01 plans 40 to 50% native effort; M0 gate; sections 2 and 9 |
| Background rendering cannot rely on the Flutter UI | AD-02, AD-03, section 5.2: native renderers, shared JSON layout spec, pre-rendered fallback buffer |
| iOS wallpaper automation is unproven | CON-03, FR-024, FR-025, section 9: M0 tests per iOS version, export fallback |
| Authenticity is an editorial process | Specific verification statuses (FR-004); content is a straight quote file with tier flags |
| Remote content from the start | AD-06, FR-028 in M2 |
| Defer the paywall | Tier flags from M1, FR-036 and FR-037 in M8 |
| Honest schedule timing | CON-02, FR-023, section 9 |
| iOS widget timelines | AD-07, FR-015 |
| Shuffle bag rather than pure random | Section 5.1 |
| FTS5 search | AD-04, FR-002 |
| Arabic and Urdu need early testing | FR-027, NFR-10, M6 gate |
| Image licensing | Backgrounds table, validator rule |
| Analytics needed to measure success | FR-038, opt-in from beta |
| All scope in one release raises risk | Riskiest-first order, Core versus Layer split, feature flags, per-milestone gates |

## 12. Open decisions

| Decision | Recommendation | Needed by |
| --- | --- | --- |
| Managed backend provider | Compare Supabase and Firebase on cost, access rules and data location | Before M7 |
| Minimum OS versions | Set from M0 results | End of M0 |
| Android widget toolkit | Glance or RemoteViews, chosen from the M0 prototype | End of M0 |
| Scenery image sources and licences | Confirm redistribution rights per source | Before M1 |
| Signing key custody and rotation | Define before first package | Before M2 |
| Sync included in free tier | Decide from measured server cost | Before M7 |
| Submissions enabled at launch | Enable only if a moderator is assigned | Before M7 |
| Arabic and Urdu fonts | Select and test candidates | During M6 |

# Lafz: Product Requirements Document

Nov 19, 2026 · @Kung FU

Lafz is a local-first mobile app that puts a user's chosen wisdom on their home screen, lock screen and wallpaper, delivered as one release and built continuously in the order set out in section 4.

## 1. Name

**Recommended working name: Lafz.** It is the Arabic, Urdu and Persian word for speech or word, short enough for an icon, easy to say in English, and it fits both the faith-oriented and the philosophy audiences. It is a recommendation only: none of the checks below have been run yet.

| Name | Meaning | Strength | Risk |
| --- | --- | --- | --- |
| **Lafz** | Word, speech | Short, resonant in Urdu and Arabic, works for scripture and philosophy | Also a term in Islamic theology; may be already used by other apps |
| Hikmah | Wisdom | Exactly on-theme | Reads as strongly Islamic; may narrow the audience |
| Axiom | A foundational principle | Broad, fits philosophy and productivity | Crowded name, hard to own |
| Stillword | A quiet word | Calm, minimalist, English-first | Less meaning for the Urdu and Arabic audience |

**Checks before committing:**

- Trademark search in the app and software classes in Pakistan, the US, the UK and the EU.
- App Store and Google Play name availability, plus domain and social handles.
- Say it aloud to 10 people from each target audience to check pronunciation and associations.
- Confirm the name does not clash with existing religious or educational products.

## 2. Product overview

**Vision.** A minimalist companion that turns a user’s chosen wisdom, beliefs and principles into a persistent visual reminder, without asking them to spend more time inside an app.

**Problem.** People who want regular reminders of ideas that matter to them have two poor options: generic quote apps built around feeds and ads, and manually changing wallpapers. Neither lets them choose trusted people and sources, show reliable attribution, and run quietly in the background.

**Product principles.** Intentionality, minimalism, authenticity, personalization, ambient delivery, privacy and graceful failure. The user opens the app occasionally to configure it; the product then works on its own.

| Goals | Non-goals |
| --- | --- |
| Let users follow curated personalities, categories and their own collections | Social feeds, public profiles, user-to-user messaging |
| Deliver quotes through widgets and rotating wallpapers on independent schedules | AI-generated quotes, AI-generated religious content, automatic translation |
| Curate reliable wisdom with clean source attribution and plan tiers | Habit tracking, journaling, streaks, gamification |
| Work fully offline, with no account needed for core use | Video wallpapers, live wallpapers, a full design editor |
| Add optional sync, community submissions and premium on top of the core | Ads of any kind |

## 3. Users

The launch audience is students, young professionals and self-improvement enthusiasts aged about 18 to 35, with a strong Islamic and philosophical library. Age is a marketing hypothesis, not an app restriction.

| Persona | Who | What they need |
| --- | --- | --- |
| A: Intentional achiever | Student, professional, founder building habits | Focus and discipline reminders; restrained, attractive design; no extra productivity app |
| B: Faith-oriented user | Follows Quran, hadith, Sahaba and scholars | Source accuracy; Arabic with translation and reference; calm, respectful design |
| C: Philosophy enthusiast | Reader, lifelong learner | Variety of perspectives; topic collections; original sources and context |

Personas A and B may want different visual tones, so the product separates content from style: themes and packs, not separate apps.

## 4. One release, built continuously

The earlier V1, V2 and V3 are merged into **one product scope and one backlog**. There are no version tiers. The work is ordered into build milestones, each shipped to testers as soon as it passes its gate, and the public launch happens when every requirement in section 5 meets its acceptance criteria.

This removes version labels, not risk. Putting accounts, sync, moderation and premium into the same scope as the core automation makes the project larger, so three rules apply:

- **Riskiest first.** The platform integrations (Android wallpaper, iOS Shortcuts, widgets) are proven before anything else is built on them.
- **Core works alone.** The app is fully usable with no account, no network and no purchase. Sync, community and premium are layers on top, switchable by feature flag.
- **Gate each milestone.** A milestone is done only when its exit criterion is met on real devices.

| Milestone | Build | Exit criterion |
| --- | --- | --- |
| M0 Feasibility sprint | Android lock-screen wallpaper, iOS Shortcuts workflow, native widgets on both platforms | Written pass or fail per integration; iOS positioning decided |
| M1 Content foundation | Straight quote file schema, 150+ curated quotes tagged by tier (free/premium), category and personality mappings | Straight quote file installs directly into local database |
| M2 Core app | Database, library, search, follow, favorites, onboarding, offline operation, signed remote content updates | Onboarding under 90 s; offline launch works; a revoked quote disappears after an update |
| M3 Rendering and rotation | Native wallpaper renderer, presets, rotation engine with shuffle bag, independent schedules | Engine tests pass; renders in 3 s or less on a mid-range device |
| M4 Widgets | Android and iOS widgets, layouts, themes, timelines, fallback | Widgets rotate for 7 days on real devices |
| M5 Automation | Android scheduled wallpaper; iOS guided Shortcuts or export fallback; health checks | 7-day soak on a Pixel and an aggressive-battery device |
| M6 Personal layer | Personal collections and quotes, advanced schedules and routines, typography and background packs, Arabic and Urdu rendering | RTL and diacritics verified on real devices |
| M7 Cloud layer | Optional sign-in, backup and sync, community submissions with moderation, creator collections, opt-in analytics | Sync conflict tests pass; moderation queue works end to end |
| M8 Premium and launch | Purchases, restore, paywall, beta hardening, store review preparation | Private beta of 20 to 50 users meets the metrics in section 8 |

## 5. Product requirements

Every requirement below belongs to the single release. **Core** requirements work with no account and no network; **Layer** requirements add optional services and can be switched off by feature flag.

### 5.1 Content and discovery (Core)

- The taxonomy is data, editable by the administrator: Islam (Quran, Prophets, Hadith, Sahaba, Scholars), History (Philosophers, Leaders, Scientists, Historical figures), Modern (Productivity, Entrepreneurs, Technology, Leadership, Mindset).
- Content path: Category, Subcategory, Personality or source, Quotes. One quote can sit in many categories without duplication.
- Browse by category and personality; search quotes, personalities, sources and categories.
- Quote detail shows text, attribution, source and reference, language, original text and translation where applicable, and plan tier (free or premium).
- Actions on a quote: favorite, follow its collection, set as widget or wallpaper quote, preview as wallpaper.

### 5.2 Personalization (Core, plus Layer where noted)

- Follow categories, subcategories, personalities and curated collections. Following adds only published, approved quotes to the user’s pool.
- Enable or disable each followed collection separately for the widget and for the wallpaper. Unfollowing removes it from future rotation; favorites stay.
- Favorites: add, remove, list, use as a rotation source, work offline.
- Recommended collections are suggested from what the user follows and favorites. Matching runs on the device, uses no AI-generated content and sends no data anywhere.
- Personal collections: users group any quotes into their own named collections (Core).
- Personal quotes: users add private quotes, shown with a Personal label (Core).
- Creator collections: curated sets from named authors, scholars or publishers, published only by the administrator (Layer).

### 5.3 Onboarding (Core)

Welcome, interests, personalities, wallpaper style, widget schedule, wallpaper schedule, add widget, automation setup. No account. Every step can be skipped and a live quote preview appears after the first choice. Basic onboarding finishes in under 90 seconds, excluding OS widget and Shortcuts setup.

### 5.4 Widgets (Core)

- Content: quote with attribution; layouts for quote only, quote with attribution, and quote with attribution and collection name.
- Backgrounds: solid, gradient, scenery, transparent where supported, light and dark.
- Sizes: the most useful native sizes per platform, including lock-screen widgets where supported.
- Schedules: every 6, 8, 12 or 24 hours, specific times of day, routine presets (morning, study, work, evening, sleep) and manual. Timing is approximate because the OS controls refresh; the interface says so.
- Next-quote and open-in-app actions where the platform allows. A bundled fallback quote appears if content cannot be read.

### 5.5 Wallpapers (Core)

- A wallpaper is a rendered composition: background, quote, attribution, optional source, typography, position and a readability overlay.
- Backgrounds: solid colors, curated HD scenery, scenery packs, and optional scenery without a quote.
- 5 to 8 polished presets (Minimal, Dark, Light, Nature, Architecture, Abstract, Editorial, Clean), with bounded choices for font, alignment, size, overlay and palette. No open-ended design editor.
- Rotation is independent of widgets, with its own collections, schedule, style and manual refresh. Preview simulates lock-screen and home-screen overlays.

### 5.6 Automation (Core)

- **Android:** scheduled wallpaper change for lock screen, home screen or both, with battery-restriction guidance and an overdue warning. A failed update never replaces the current wallpaper.
- **iOS:** guided Shortcuts setup with a test step and troubleshooting, only if the feasibility sprint proves it reliable. The interface never promises silent rotation unless validated.
- **Fallback on both platforms:** one-tap save of any wallpaper to Photos or Files at the correct size.

### 5.7 Languages (Core)

English, Arabic and Urdu, with right-to-left layout, diacritics and bundled fonts. Arabic or Urdu content is enabled only after rendering passes on real devices. Translations carry their source.

### 5.8 Accounts, backup and sync (Layer)

Optional sign-in with Apple or Google, used only for backup, sync and community submissions. Synced data: followed collections, favorites, personal collections, personal quotes, settings and themes. Users can delete their account and all server data from inside the app.

### 5.9 Community suggestions (Layer)

Signed-in users can suggest quotes with attribution and source. Users can suggest corrections from quote detail. No public profiles, comments or feeds.

### 5.10 Content updates (Core)

Direct JSON content updates refresh the library and quote pool without an app store release. A bad update is rejected and the last valid library stays.

### 5.11 Premium (Layer)

Free and premium tiers. Purchases, restore and entitlement checks use the platform stores only. Content is tagged as free or premium at the quote, collection and background level.

### 5.12 Settings, privacy and analytics (Core)

Schedules, collections, appearance, font, size, alignment, attribution and source visibility, theme, language, automation setup, privacy summary, restore purchases and about. Analytics are opt-in, minimal and never include quote text or personal identifiers.

## 6. Content library and plan tiers

Lafz utilizes a straight, transparent JSON content structure (`baseline_content.json`) that groups wisdom by categories, subcategories, and personalities, with direct tier segmentation (`free` and `premium`).

- **Straight Quote File**: Quotes are maintained directly in structured JSON without complex validation scripts, multi-signature packaging, or multi-stage editorial review queues.
- **Plan Tiers**:
  - **Free Tier**: Access to core categories, foundational thinkers, and selected daily wisdom.
  - **Premium Tier**: Expands access to full collections, advanced categories, creator collections, and exclusive typography/presets.
- **Islamic Content**: Accurately records surah and ayah for Quranic verses, and collection/reference/grading for Hadith alongside original Arabic text and translation.
- **Attribution & Sources**: Each quote clearly attributes the speaker, original text, and documented publication or reference.

## 7. Success metrics

The north-star metric is **weekly active users with at least one active personalized reminder surface**. App opens matter less, because a user may rarely open the app and still get value daily. All targets are beta hypotheses, not benchmarks.

| Metric | Target |
| --- | --- |
| Onboarding completion | 70% or more |
| Time to first personalized quote | 60 seconds or less |
| First widget setup completed | 50% or more |
| First wallpaper setup completed | 40% or more |
| Users following at least one collection | 80% or more |
| Day-7 retention | 20% or more |
| Rotation still enabled after 7 days | 50% or more |
| iOS guided Shortcuts setup success | 80% or more |
| Crash-free sessions | 99% or more |
| Wallpaper generation success | 99% or more |

Supporting metrics: active widgets, active wallpaper rotation, quotes favorited, collections followed, rotation-disabled rate, premium conversion, cancellation rate, content error reports. Measuring these needs the opt-in analytics from section 5.12, active from the private beta.

## 8. Risks and mitigations

| Risk | Severity | Mitigation |
| --- | --- | --- |
| iOS wallpaper automation is limited or unreliable | Critical | M0 gate with written verdict; widgets plus one-tap export as fallback positioning |
| Quote attribution errors | Medium | Clean source citation, straightforward correction updates |
| Single scope is too large to finish | High | Riskiest-first order, feature flags, core works without any layer, gated milestones |
| Widget refresh limits | High | Pre-generated timelines on iOS; interval wording says approximate |
| Android background restrictions on some phones | Medium-high | Native workers, health screen, device test matrix |
| Copyright on quotes, translations and images | High | Rights and licence tracked per record and per image |
| Community submissions bring moderation load and abuse | High | Admin-only publication, report button, rate limits, submission can be switched off |
| Account and sync add privacy obligations | Medium-high | Sign-in optional, minimal data, in-app account deletion, accurate store privacy labels |
| Sacred text shown disrespectfully | Medium | Display rules, testing with Persona B, Arabic enabled only after rendering passes |
| Low retention or weak monetization | High | Track active rotation, test annual and lifetime, premium defined by ongoing value |
| Store review rejection | Medium-high | Accurate claims about automation, compliant purchases and moderation |

## 9. Review feedback adopted

These points from the review of the original approach are built into this PRD. The matching technical changes are in the SRS.

| Feedback | Where it appears here |
| --- | --- |
| Platform integrations are the product, not an add-on to a Flutter app | M0 feasibility gate comes first; sections 4 and 9 |
| iOS wallpaper automation is unproven | Section 5.6: gated guided setup, export fallback on both platforms |
| Straightforward quote management | Section 6: straight JSON quote file with tier tags (free, premium) |
| 100 to 200 quotes is too few to test following | Section 6: 12 to 20 quotes per personality, 300 to 450 for beta |
| Deliver content remotely from the start | Section 5.10: signed content updates in the core |
| Defer the paywall | Tier flags from M1, purchases in M8 |
| Be honest about schedule timing | Section 5.4: intervals described as approximate |
| Image licensing is a separate legal track | Section 6: per-image licence and attribution |
| Arabic and sacred text need early care | Sections 5.7 and 6: verified rendering and display rules |
| Analytics are needed to measure success | Section 5.12: opt-in minimal analytics from beta |
| Name needs checking | Section 1: recommended name with checks owed |
| Merging all versions raises risk | Section 4: riskiest-first order, core works alone, feature flags |

## 10. Open decisions

| Decision | Recommendation | Needed by |
| --- | --- | --- |
| Final name | Run the section 1 checks; Lafz is the working choice | Before design work |
| Minimum OS versions | Set after the feasibility sprint | End of M0 |
| iOS headline positioning | Widgets and export first; Shortcuts as a bonus unless proven | End of M0 |
| Licensing for Quran translations, scenery and modern quotes | Confirm per source | Before M1 |
| Second reviewer for Islamic content | Appoint one | Before M1 |
| Whether sync is free or premium | Decide from measured server cost | Before M7 |
| Community submissions at launch | Keep behind a flag; enable if moderation capacity exists | Before M7 |
| Arabic and Urdu at launch | Enable only if rendering tests pass | End of M6 |

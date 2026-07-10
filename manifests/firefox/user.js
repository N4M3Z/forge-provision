// forge-provision Firefox hardening — deployed into the active profile by
// scripts/configure/firefox.sh. Moderate, daily-driver-safe: kills telemetry,
// studies, sponsored content, and speculative network chatter without breaking
// logins or Firefox Sync. Aggressive, site-breaking prefs are left commented at
// the bottom to opt into per machine.
//
// Reference (canonical, exhaustive): https://github.com/arkenfox/user.js
// Each pref is applied at every launch; change it live and it resets next start.

// === Telemetry and data reporting ===
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.ping-centre.telemetry", false);

// === Studies, experiments, and recommendation pings ===
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");
user_pref("browser.discovery.enabled", false);

// === Crash reports ===
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

// === New tab: sponsored content and activity-stream telemetry ===
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("extensions.pocket.enabled", false);

// === Address bar: no sponsored / Firefox Suggest network suggestions ===
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.trending.featureGate", false);

// === Speculative and prefetch network activity ===
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.send_pings", false);

// === Tracking protection and transport ===
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// === Aggressive / site-breaking — opt in per machine, keep commented by default ===
// Clears cookies + site data on every shutdown (logs you out everywhere):
// user_pref("network.cookie.lifetimePolicy", 2);
// Resist fingerprinting: spoofs timezone, screen size, canvas; letterboxes windows:
// user_pref("privacy.resistFingerprinting", true);
// First-party isolation (breaks some federated logins and embeds):
// user_pref("privacy.firstparty.isolate", true);

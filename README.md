# openGym for Home Assistant

A workout and gym log app for Home Assistant: it runs [openGym](https://github.com/DuarteSantos8/openGym) in the Home Assistant sidebar, behind Home Assistant's own login.

This is a repackaging of openGym by its author, Duarte Santos, not a fork. Home Assistant builds it on your machine from the official openGym images, pinned to one version (1.4.3 for now) by tag and digest. Nothing of openGym is changed except two headers that let the page show inside Home Assistant (see [What this touches](#what-this-touches)). Report openGym bugs [upstream](https://github.com/DuarteSantos8/openGym/issues), packaging bugs [here](https://github.com/misterblokhead/ha-opengym/issues).

## Install

[![Open your Home Assistant instance and add this app repository.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fmisterblokhead%2Fha-opengym)

Or by hand:

1. In Home Assistant, open **Settings > Apps > Install apps** (the page is called App store), open the three-dot menu at the top right, choose **Repositories** and then **Add**, and add `https://github.com/misterblokhead/ha-opengym`.
2. Install **openGym**. If you open Home Assistant at your own domain, set `address` on its Configuration tab now, before the first start, for example `https://home.example.com`.
3. Start it and switch on **Show in sidebar**.
4. Switch on **Watchdog**. If openGym stops working, the app stops, and Home Assistant restarts it only when Watchdog is on.

The app needs one address: the https address people open Home Assistant at. It looks for it in this order:

1. The `address` option, if you set it.
2. Home Assistant's https external URL.
3. The Nabu Casa address, when remote access is on.

If none is found, or the address is not https, has a path or is an IP address (passkeys never work on one), the app does not start and the app's Log tab tells you to set `address`.

## Options

| Option | Default | What it does |
| --- | --- | --- |
| `address` | empty | The https address people open Home Assistant at. Empty means detect it. |
| `invite_only` | `false` | Only people with an invite can make a profile. |
| `first_user_admin` | `true` | The first profile made becomes the admin. |

## First profile, then invite only

Make your own profile first (the button is called **Create new profile**). Then switch `invite_only` on and restart the app.

Do not switch it on from the start. With it on, nobody can make the first profile.

## Use it in a browser

Open Home Assistant in Chrome (or another browser) at its https address and use openGym from the sidebar. Passkeys work there.

Do not use the Home Assistant phone app. Its built-in browser cannot do passkeys. On your phone, open Home Assistant in the phone's browser and add it to the home screen.

## Never change the address after people have signed up

Passkeys are tied to the address they were made at. The app stores the address once openGym holds data (from its second start on). If the address changes later, the log warns that passkeys made for the old address stop working, and repeats the warning on every start. Set the old address back to make them work again.

## openGym's own phone app

openGym has its own phone app. It cannot connect through Nabu Casa, because every request needs a Home Assistant login. If you want to use it, run openGym on its own address instead, for example over Tailscale. See the openGym section of the [ChallengeHouse README](https://github.com/misterblokhead/ha-challengehouse) (route B).

## What this touches

**Permissions.** The app asks for one: `homeassistant_api`. It is used only when `address` is empty, by [`address.mjs`](opengym/address.mjs) at start-up, over the Supervisor's Core websocket (`ws://supervisor/core/websocket`) with three messages: `auth`, `get_config` (to read the external URL) and `cloud/status` (to read whether Nabu Casa remote access is on and its address). Nothing is written to Home Assistant. [`run.sh`](opengym/run.sh) then removes the token from the environment before it starts openGym and nginx. It does not ask for the Supervisor API, host network, devices, or access to your Home Assistant config folder.

Note that this token can use Home Assistant's API with full rights, and openGym runs as root in the same container, so it could still read the token from the start-up process. Setting `address` yourself does not take the permission away; the permission is what makes address detection work.

**Ports.** None on your network. openGym is reachable only through Home Assistant's ingress (the sidebar), on port 8099 inside Home Assistant's internal app network. The openGym API also listens on port 3000 inside that same internal network.

**Outbound calls.** The app's own code makes none apart from the Supervisor call above. No telemetry. Nothing is downloaded at start-up. When Home Assistant builds the app (install and update), it pulls the two openGym images from `ghcr.io` and installs `nginx` and `gettext` from Alpine's package mirrors. openGym itself only reaches out for features you switch on in it, such as push notifications and webhooks.

**Data.** Everything lives in the app's `/data` folder, which Home Assistant includes in its backups: `/data/opengym` (openGym's users, passkeys, workouts and uploads) and `/data/address` (the stored address).

**The two header changes.** openGym forbids being shown in a frame. The build changes `X-Frame-Options` from `DENY` to `SAMEORIGIN` and the Content Security Policy's `frame-ancestors` from `'none'` to `'self'`, so the page can show inside Home Assistant and nowhere else. The build fails if either change does not apply.

**The visitor's real address.** openGym limits sign-in attempts per address. Requests come in through Home Assistant, so [`realip.conf`](opengym/realip.conf) tells nginx to trust `X-Forwarded-For` from Home Assistant's internal network (`172.30.32.0/23`) and take the last address added from outside it. Home Assistant adds the address it sees the browser connect from, so when Home Assistant is reached directly a browser cannot fake it. Other apps on the same internal network can.

## How this is made

Built with Claude Code and reviewed by a human before each release. Every push is checked in CI by the Home Assistant app linter and by a startup test ([`tests/startup.sh`](tests/startup.sh)) that builds the image for amd64 and checks that:

- the app refuses to start with an address that has a path, or with an IPv4 or IPv6 address;
- with a good address it starts and openGym's health check answers ok;
- the two changed headers are served;
- openGym uses the address's host name for passkeys;
- the address is stored only once openGym holds data, and a changed address is logged while the stored one is kept.

The test does not cover address detection through Home Assistant, ingress or the real-address handling, or the aarch64 build. A CodeQL scan checks `address.mjs`.

## Updates

Each release is pinned to one openGym version. The [changelog](opengym/CHANGELOG.md) names it. Home Assistant offers a backup before it updates an app.

The app has its own version, separate from openGym's, so packaging fixes can ship on their own. To release:

1. Bump `version` in [`opengym/config.yaml`](opengym/config.yaml).
2. Add a `## [X.Y.Z] (openGym A.B.C)` section at the top of the [changelog](opengym/CHANGELOG.md).
3. Tag the commit `vX.Y.Z` and push the tag. The release workflow checks that the tag matches the version and creates the GitHub release from that changelog section.

## Links

- [ChallengeHouse](https://github.com/misterblokhead/ha-challengehouse) uses this app for gym tracking.
- [openGym](https://github.com/DuarteSantos8/openGym) is the project this repackages ([GitLab mirror](https://gitlab.com/DuarteSantos8/opengym)).
- [mzspicoli/opengym-homeassistant](https://github.com/mzspicoli/opengym-homeassistant) is the other community app for openGym. This one differs by using the official images pinned to a version, and by handling the passkey address (detecting it, storing it, warning when it changes).

## Licence

This repository (the packaging) is MIT. openGym is © Duarte Santos and licensed under the [GNU AGPL v3.0](https://github.com/DuarteSantos8/openGym/blob/main/LICENSE); its source is at [github.com/DuarteSantos8/openGym](https://github.com/DuarteSantos8/openGym). The exercise stills and animations inside the openGym images are not covered by the AGPL: they are licensed to openGym by Gym visual for use in openGym only (see openGym's [NOTICE](https://github.com/DuarteSantos8/openGym/blob/main/NOTICE.md)).

## Sponsors

This app is free. If it is useful to you, you can support its development through [GitHub Sponsors](https://github.com/sponsors/misterblokhead).

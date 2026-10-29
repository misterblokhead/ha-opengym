# openGym for Home Assistant

A Home Assistant app that runs [openGym](https://gitlab.com/DuarteSantos8/opengym), a self-hosted gym log, in the Home Assistant sidebar.

This is a repackaging. Home Assistant builds it on your machine from the official openGym images, pinned to one version (1.4.3 for now). Nothing of openGym is changed except two headers (`X-Frame-Options SAMEORIGIN` and CSP `frame-ancestors 'self'`) that let the page show inside Home Assistant. The app also passes each visitor's real address to openGym, which it uses for its sign-in attempt limits.

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

## Updates

Each release is pinned to one openGym version. The [changelog](opengym/CHANGELOG.md) names it. Home Assistant offers a backup before it updates an app.

## Links

- [ChallengeHouse](https://github.com/misterblokhead/ha-challengehouse) uses this app for gym tracking.
- [openGym](https://gitlab.com/DuarteSantos8/opengym) is the project this repackages.
- [mzspicoli/opengym-homeassistant](https://github.com/mzspicoli/opengym-homeassistant) is the other community app for openGym. This one differs by using the official images pinned to a version, and by handling the passkey address (detecting it, storing it, warning when it changes).

## Licence

This repository is MIT. openGym itself is AGPL-3.0.

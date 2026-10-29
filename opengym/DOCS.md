# openGym

A self-hosted gym log in your Home Assistant sidebar. It runs the official [openGym](https://gitlab.com/DuarteSantos8/opengym) images, pinned to one version.

## Setup

1. Set `address` if you open Home Assistant at your own domain, for example `https://home.example.com`. Do this before the first start.
2. Start the app and switch on **Show in sidebar**.
3. Switch on **Watchdog**. If openGym stops working, the app stops, and Home Assistant restarts it only when Watchdog is on.

## Address

The app needs the https address people open Home Assistant at. It uses the `address` option, else Home Assistant's https external URL, else the Nabu Casa address when remote access is on. If none is found, or the address is not https, has a path or is an IP address (passkeys never work on one), the app does not start and the app's Log tab says to set `address`.

Do not change the address after people have signed up. Passkeys are tied to it. The app stores it once openGym holds data (from its second start on). If it changes, the log warns that passkeys made for the old address stop working. Set the old address back to make them work again.

## Invite only

Make your own profile first (**Create new profile**). Then switch `invite_only` on and restart. With it on from the start, nobody can make the first profile.

`first_user_admin` (default on) makes the first profile the admin.

## Use it in a browser

Open Home Assistant in Chrome (or another browser) at its https address. Passkeys work there. They do not work in the Home Assistant phone app, so on your phone use the phone's browser and add it to the home screen.

openGym's own phone app cannot connect through Nabu Casa. It needs openGym on its own address.

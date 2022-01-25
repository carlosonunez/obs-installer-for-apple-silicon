# obs-installer-for-apple-silicon

Use this script to conveniently build the latest version of OBS on Apple M1 Macs and MacBooks.

This build includes:

* Mac Virtual Camera, and
* Noise Suppression Filters (RNNoise, Speex).

## How to Use

> **NOTE**: An experimental version of an official ARM-based OBS app
> exists. Skip to [this](#download-experimental-official-build-v120-and-above) section
> to use this script to download and install it.

From a Terminal (⌘-Space, type "Terminal"), simply:

1. Clone this repository: `git clone https://github.com/carlosonunez/obs-installer-for-apple-silicon`, then
2. Install: `cd obs-installer-for-apple-silicon && ./install.sh`

If you want to build a specific version of OBS (that's greater than version 27.0.1),
run this:

```sh
OBS_VERSION=[VERSION] ./install.sh
```

**NOTE**: This script downloads OBS and its dependencies for you. If you wish to keep them
after installation completes, run this instead:
`REMOVE_INSTALLATION_DIRS=false ./install.sh`

Run `./install.sh --help` or `./install.sh -h` to view all of your options.

## Download Experimental Official Build (v1.2.0 and above)

A [fork](https://github.com/PatTheMav/obs-studio/tree/universal-build) of the
OBS Studio project is building and storing "official" ARM-native OBS builds.
To use `./install.sh` to retrieve these builds, follow these instructions:

1. Create a GitHub App. Go
   [here](https://docs.github.com/en/developers/apps/building-github-apps/creating-a-github-app)
   to learn how to do this.

   After you create your app, you'll be given a `Client ID`. Keep this page
   open, as you'll need it in a few steps from now.

2. Set the callback URL of your new App to "http://localhost:4567"
   
3. Give your new app `read-only` permission to the Actions API. Go
   [here](https://docs.github.com/en/developers/apps/managing-github-apps/editing-a-github-apps-permissions)
   to learn how to do that.
4. Go back to the App's summary page (the page that shows you its `Client ID`).
   Click the "Generate A New Client Secret" button. A random string will show up
   underneath it.

   This is your client secret. It will only be shown once.
5. Go back to your terminal and run `./install.sh` like this:

   ```sh
   USE_EXPERIMENTAL_UNIVERSAL_BUILD=true \
   GH_CLIENT_ID=<your_github_app_client_id> \
   GH_CLIENT_SECRET=<your_github_app_client_secret> \
   ./install.sh
   ```
5. Once OBS finishes downloading and decompressing, you'll be shown a window
   prompting you to move OBS into your Applications folder. Do that.

## About VB-Cable

VB-Cable does not come bundled with OBS. If you need VB-Cable/VoiceMeeter/Banana/etc.,
download it from https://vb-audio.com/Cable/.

## Problems? Feedback?

Please raise a GitHub issue with any feedback, questions, or concerns! Note that this project
is supported on a best-effort basis. I'll add automated testing once GitHub Actions
supports Apple M1 runners.

## Errata

### Missing items

The following items are missing from mainline OBS:

- OBS Lua scripting
- Browser support (though its build flag is enabled and Chromium is bundled in)

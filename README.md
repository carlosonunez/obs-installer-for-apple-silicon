# obs-installer-for-apple-silicon

Use this script to conveniently build the latest version of OBS on Apple M1 Macs and MacBooks.

This build includes:

* Mac Virtual Camera, and
* Noise Suppression Filters (RNNoise, Speex).

## How to Use

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

fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios register_app

```sh
[bundle exec] fastlane ios register_app
```

Create the App Store Connect app record + bundle IDs (idempotent)

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload metadata to App Store Connect (no screenshots, no binary, no submit)

### ios submit_release

```sh
[bundle exec] fastlane ios submit_release
```

Upload metadata to the draft version, attach latest build, and submit for review

### ios ship_testflight

```sh
[bundle exec] fastlane ios ship_testflight
```

Build and upload to TestFlight

### ios push

```sh
[bundle exec] fastlane ios push
```

Build, upload to TestFlight, then tag and push to GitHub

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

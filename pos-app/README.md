# Berkah POS App

Flutter client for Berkah POS, with point-of-sale checkout, inventory lot tracking, and accounting journal functionality.

## Local checks

Run these commands from this directory:

```sh
flutter pub get
flutter analyze
flutter test
```

## Android release artifact

On pushes to `main` that change `pos-app/**`, the `02 · UAT Infinix Release APK` workflow runs secret scanning, static analysis, tests, and a release App Bundle build.

The artifact is published as `berkahtigaputeri-pos-release-aab`. Because this repository currently contains only a partial Android host directory, the workflow generates the missing Android scaffold in its temporary checkout when needed.

The CI scaffold step constrains Gradle to the Java 17 JDK selected by `actions/setup-java`, caps the heap at 2 GiB, and limits parallel workers to reduce memory pressure on the self-hosted Fedora runner.
# auto-start test 1791672616

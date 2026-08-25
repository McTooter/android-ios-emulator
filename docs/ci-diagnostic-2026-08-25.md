# CI Diagnostic — 2026-08-25

The checkout is synchronized with `origin/master` at commit `5852e61` (`Document UTM build findings`), with no local modifications. The pinned UTM submodule is `8e4de50817e76a83d6840212311627a78dd4f8b2`.

The latest push run `32881915121` and manual run `32882125047` both concluded `failure`. The manual run started at 18:09:42Z and both jobs ended within approximately three seconds with zero steps, no runner name, and no downloadable logs. Repository Actions are enabled and allow all actions. This indicates a GitHub runner-service/capacity rejection rather than a shell-step failure; the API does not expose a more specific message and the unauthenticated web page is unavailable.

The prior runner-backed run `32870609069` used a GitHub-hosted runner and its custom `build` job succeeded. The companion UTM job used a runner but failed before the dependency build completed. Its available failure log reports the older workflow invoking `./scripts/build_dependencies.sh -p ios -a arm64` and failing the environment check with `'six' not found in your Python 3 installation.` This predates the current virtualenv setup, which must still be verified on a fresh runner.

Only unsigned custom-app artifacts are currently present. There is no UTM/QEMU archive artifact. The current UTM script creates `sysroot-iOS-arm64` because `PLATFORM_FAMILY_PREFIX` is `iOS`, so cache paths must use that exact case. The upstream workflow caches sysroots keyed by platform/architecture plus dependency script and patches; the project workflow currently rebuilds from scratch and does not cache or upload the dependency log on failure.

No guest image, Android boot, APK installation, or device launch has been verified. Do not claim arbitrary APK execution.

"""Patch the vendored UTM iOS target into the AndroidRuntime target.

The UTM submodule remains pristine. This patch is applied only in CI to the
working checkout before the integrated archive is built. It reuses UTM's
existing iOS target, QEMU frameworks, resources, package dependencies, and
embed phases; it does not modify signing, entitlements, or JIT behavior.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "vendor" / "UTM" / "UTM.xcodeproj" / "project.pbxproj"

FILES = (
    ("A7D000000000000000000001", "A7D000000000000000000101", "Models.swift"),
    ("A7D000000000000000000002", "A7D000000000000000000102", "RuntimeCapabilities.swift"),
    ("A7D000000000000000000003", "A7D000000000000000000103", "RuntimeController.swift"),
    ("A7D000000000000000000004", "A7D000000000000000000104", "GuestConfiguration.swift"),
    ("A7D000000000000000000005", "A7D000000000000000000105", "UTMRuntimeSession.swift"),
    ("A7D000000000000000000006", "A7D000000000000000000106", "ContentView.swift"),
)


def add_once(text: str, marker: str, block: str) -> str:
    if block.strip() in text:
        return text
    index = text.index(marker)
    return text[:index] + block + text[index:]


def main() -> None:
    text = PROJECT.read_text(encoding="utf-8")
    for file_ref, build_ref, name in FILES:
        ref_block = (
            f"\t\t{file_ref} /* {name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = sourcecode.swift; path = ../../iPadApp/{name}; "
            f"sourceTree = \"<group>\"; }};\n"
        )
        build_block = (
            f"\t\t{build_ref} /* {name} in Sources */ = {{isa = PBXBuildFile; "
            f"fileRef = {file_ref} /* {name} */; }};\n"
        )
        text = add_once(text, "/* End PBXFileReference section */\n", ref_block)
        text = add_once(text, "/* End PBXBuildFile section */\n", build_block)

    source_phase = "CE2D926924AD46670059923A /* Sources */ = {"
    phase_start = text.index(source_phase)
    phase_end = text.index("\n\t\t};", phase_start)
    phase = text[phase_start:phase_end]
    insertion = ""
    for _, build_ref, name in FILES:
        line = f"\t\t\t\t{build_ref} /* {name} in Sources */,\n"
        if line not in phase:
            insertion += line
    if insertion:
        files_marker = "\t\t\tfiles = (\n"
        files_index = phase.index(files_marker) + len(files_marker)
        phase = phase[:files_index] + insertion + phase[files_index:]
        text = text[:phase_start] + phase + text[phase_end:]

    # The original UTM iOS target conditionally compiles its own JIT and
    # memory-limit hooks. This project intentionally builds without those
    # behaviors; external user setup remains outside the app.
    for config_id in (
        "CE2D93BC24AD46670059923A /* Debug */ = {",
        "CE2D93BD24AD46670059923A /* Release */ = {",
    ):
        start = text.index(config_id)
        end = text.index("\n\t\t};", start)
        block = text[start:end]
        block = block.replace('\t\t\t\t\t"WITH_JIT=1",\n', "")
        block = block.replace(
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "WITH_JIT WITH_SOLO_VM WITH_USB WITH_LOCATION_BACKGROUND $(inherited)";',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "ANDROID_RUNTIME_UTM ANDROID_RUNTIME_SHELL WITH_SOLO_VM WITH_USB WITH_LOCATION_BACKGROUND $(inherited)";',
        )
        text = text[:start] + block + text[end:]

    # Give the adapted iOS target the AndroidRuntime identity while retaining
    # UTM's required Info.plist capabilities and resources.
    for config_id in (
        "CE2D93BC24AD46670059923A /* Debug */ = {",
        "CE2D93BD24AD46670059923A /* Release */ = {",
    ):
        start = text.index(config_id)
        end = text.index("\n\t\t};", start)
        block = text[start:end]
        block = block.replace(
            'PRODUCT_BUNDLE_IDENTIFIER = "$(PRODUCT_BUNDLE_PREFIX:default=com.utmapp).UTM";',
            'PRODUCT_BUNDLE_IDENTIFIER = com.example.androidruntime;',
        )
        block = block.replace(
            'PRODUCT_NAME = "$(PROJECT_NAME)";',
            'PRODUCT_NAME = AndroidRuntime;',
        )
        if "INFOPLIST_KEY_CFBundleDisplayName" not in block:
            block = block.replace(
                "PRODUCT_NAME = AndroidRuntime;\n",
                "PRODUCT_NAME = AndroidRuntime;\n\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Android Runtime\";\n",
                1,
            )
        text = text[:start] + block + text[end:]

    # Keep UTM's own home ContentView available to its legacy window view under
    # another name, then let the custom ContentView become the app root.
    shared_content = ROOT / "vendor" / "UTM" / "Platform" / "Shared" / "ContentView.swift"
    shared_text = shared_content.read_text(encoding="utf-8")
    shared_text = shared_text.replace("struct ContentView: View", "struct UTMHomeContentView: View", 1)
    shared_text = shared_text.replace("struct ContentView_Previews: PreviewProvider", "struct UTMHomeContentView_Previews: PreviewProvider", 1)
    shared_text = shared_text.replace("ContentView()", "UTMHomeContentView()")
    shared_content.write_text(shared_text, encoding="utf-8")

    single_window = ROOT / "vendor" / "UTM" / "Platform" / "iOS" / "UTMSingleWindowView.swift"
    single_text = single_window.read_text(encoding="utf-8")
    single_text = single_text.replace("ContentView().environmentObject(data!)", "UTMHomeContentView().environmentObject(data!)")
    single_window.write_text(single_text, encoding="utf-8")

    app = ROOT / "vendor" / "UTM" / "Platform" / "iOS" / "UTMApp.swift"
    app_text = app.read_text(encoding="utf-8")
    old_root = "            UTMSingleWindowView(data: data)"
    new_root = "            ContentView()"
    if old_root in app_text:
        app_text = app_text.replace(old_root, new_root, 1)
    elif new_root not in app_text:
        raise SystemExit("UTMApp root expression not found")
    app.write_text(app_text, encoding="utf-8")

    PROJECT.write_text(text, encoding="utf-8")
    print("Patched UTM iOS target for AndroidRuntime")


if __name__ == "__main__":
    main()

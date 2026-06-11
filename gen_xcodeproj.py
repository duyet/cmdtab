#!/usr/bin/env python3
"""Generate MinhAgent.xcodeproj (iOS + macOS app targets) for the MinhAgent sources.

This mirrors the canonical swiftc builds (build.sh / build_ios.sh):
  - iOS target  : Sources/Shared + Sources/iOS, Info.plist = Resources/iOS_Info.plist
  - macOS target: Sources/Shared + Sources/macOS, Info.plist = Info.plist
No external dependencies; frameworks (UIKit, AppKit, FoundationModels, …) auto-link
via `import`. Hand-rolled pbxproj so it works without XcodeGen/Tuist.
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.abspath(__file__))

def uid(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()

def swift_files(rel_dir: str):
    d = os.path.join(ROOT, rel_dir)
    return sorted(
        f"{rel_dir}/{n}" for n in os.listdir(d) if n.endswith(".swift")
    )

shared = swift_files("Sources/Shared")
ios_only = swift_files("Sources/iOS")
mac_only = swift_files("Sources/macOS")

objects = []  # list of (id, body_string)

def add(obj_id, body):
    objects.append((obj_id, body))

# ---- File references for every source file (one shared ref per path) ----
file_refs = {}  # rel_path -> fileRef id
def file_ref(path):
    if path in file_refs:
        return file_refs[path]
    fid = uid("fileRef:" + path)
    name = os.path.basename(path)
    add(fid, f'{fid} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
             f'path = "{name}"; sourceTree = "<group>"; }};')
    file_refs[path] = fid
    return fid

# Build a per-target Sources phase with its own PBXBuildFile entries.
def sources_phase(target_key, paths):
    build_file_ids = []
    for p in paths:
        fref = file_ref(p)
        bid = uid(f"buildFile:{target_key}:{p}")
        add(bid, f'{bid} = {{isa = PBXBuildFile; fileRef = {fref}; }};')
        build_file_ids.append((bid, os.path.basename(p)))
    phase_id = uid(f"sourcesPhase:{target_key}")
    files = "\n".join(f"\t\t\t\t{bid} /* {name} in Sources */," for bid, name in build_file_ids)
    add(phase_id, f'''{phase_id} = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{files}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')
    return phase_id

# ---- Group of source file refs (flat, grouped by folder) ----
def group(name, paths, seed):
    gid = uid("group:" + seed)
    children = "\n".join(f"\t\t\t\t{file_ref(p)} /* {os.path.basename(p)} */," for p in paths)
    add(gid, f'''{gid} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children}
\t\t\t);
\t\t\tpath = "{name}";
\t\t\tsourceTree = "<group>";
\t\t}};''')
    return gid

shared_group = group("Shared", shared, "Shared")
ios_group = group("iOS", ios_only, "iOS")
mac_group = group("macOS", mac_only, "macOS")

# Sources parent group
sources_group = uid("group:Sources")
add(sources_group, f'''{sources_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{shared_group} /* Shared */,
\t\t\t\t{ios_group} /* iOS */,
\t\t\t\t{mac_group} /* macOS */,
\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};''')

# Info.plist file refs
ios_plist_ref = uid("fileRef:iOSInfo")
add(ios_plist_ref, f'{ios_plist_ref} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; '
                   f'path = "Resources/iOS_Info.plist"; sourceTree = "<group>"; }};')
mac_plist_ref = uid("fileRef:macInfo")
add(mac_plist_ref, f'{mac_plist_ref} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; '
                   f'path = "Info.plist"; sourceTree = "<group>"; }};')

# Product refs (.app)
ios_product = uid("product:ios")
add(ios_product, f'{ios_product} = {{isa = PBXFileReference; explicitFileType = wrapper.application; '
                 f'includeInIndex = 0; path = "MinhAgent_iOS.app"; sourceTree = BUILT_PRODUCTS_DIR; }};')
mac_product = uid("product:mac")
add(mac_product, f'{mac_product} = {{isa = PBXFileReference; explicitFileType = wrapper.application; '
                 f'includeInIndex = 0; path = "MinhAgent.app"; sourceTree = BUILT_PRODUCTS_DIR; }};')

products_group = uid("group:Products")
add(products_group, f'''{products_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ios_product} /* MinhAgent_iOS.app */,
\t\t\t\t{mac_product} /* MinhAgent.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};''')

# Main group
main_group = uid("group:main")
add(main_group, f'''{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{sources_group} /* Sources */,
\t\t\t\t{ios_plist_ref} /* Resources/iOS_Info.plist */,
\t\t\t\t{mac_plist_ref} /* Info.plist */,
\t\t\t\t{products_group} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};''')

# Empty Frameworks + Resources phases per target
def empty_phase(isa, seed):
    pid = uid(seed)
    add(pid, f'''{pid} = {{
\t\t\tisa = {isa};
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')
    return pid

ios_src = sources_phase("ios", shared + ios_only)
mac_src = sources_phase("mac", shared + mac_only)
ios_fw = empty_phase("PBXFrameworksBuildPhase", "fw:ios")
mac_fw = empty_phase("PBXFrameworksBuildPhase", "fw:mac")
ios_res = empty_phase("PBXResourcesBuildPhase", "res:ios")
mac_res = empty_phase("PBXResourcesBuildPhase", "res:mac")

# ---- Build configurations ----
def build_config(seed, name, settings):
    cid = uid(seed)
    lines = "\n".join(f'\t\t\t\t{k} = {v};' for k, v in settings.items())
    add(cid, f'''{cid} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{lines}
\t\t\t}};
\t\t\tname = {name};
\t\t}};''')
    return cid

def config_list(seed, debug_id, release_id):
    lid = uid(seed)
    add(lid, f'''{lid} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_id} /* Debug */,
\t\t\t\t{release_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};''')
    return lid

# Project-level settings
proj_common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "SWIFT_VERSION": "5.0",
    "CLANG_ENABLE_MODULES": "YES",
}
proj_debug = build_config("cfg:proj:debug", "Debug", {**proj_common,
    "ONLY_ACTIVE_ARCH": "YES", "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    "GCC_OPTIMIZATION_LEVEL": "0", "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"})
proj_release = build_config("cfg:proj:release", "Release", {**proj_common,
    "SWIFT_OPTIMIZATION_LEVEL": '"-O"', "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO"})
proj_cfg_list = config_list("cfglist:proj", proj_debug, proj_release)

# iOS target settings
ios_settings = {
    "PRODUCT_NAME": "MinhAgent_iOS",
    "PRODUCT_BUNDLE_IDENTIFIER": "app.minhagent.ios",
    "INFOPLIST_FILE": '"Resources/iOS_Info.plist"',
    "GENERATE_INFOPLIST_FILE": "NO",
    "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
    "SDKROOT": "iphoneos",
    'SUPPORTED_PLATFORMS': '"iphoneos iphonesimulator"',
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "CODE_SIGN_IDENTITY": '"-"',
    "CODE_SIGN_STYLE": "Automatic",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "ENABLE_PREVIEWS": "YES",
    "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS": "NO",
}
ios_dbg = build_config("cfg:ios:debug", "Debug", ios_settings)
ios_rel = build_config("cfg:ios:release", "Release", ios_settings)
ios_cfg_list = config_list("cfglist:ios", ios_dbg, ios_rel)

# macOS target settings
mac_settings = {
    "PRODUCT_NAME": "MinhAgent",
    "PRODUCT_BUNDLE_IDENTIFIER": "app.minhagent.macos",
    "INFOPLIST_FILE": '"Info.plist"',
    "GENERATE_INFOPLIST_FILE": "NO",
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "SDKROOT": "macosx",
    "CODE_SIGN_IDENTITY": '"-"',
    "CODE_SIGN_STYLE": "Automatic",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "ENABLE_PREVIEWS": "YES",
    "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS": "NO",
}
mac_dbg = build_config("cfg:mac:debug", "Debug", mac_settings)
mac_rel = build_config("cfg:mac:release", "Release", mac_settings)
mac_cfg_list = config_list("cfglist:mac", mac_dbg, mac_rel)

# Native targets
ios_target = uid("target:ios")
add(ios_target, f'''{ios_target} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ios_cfg_list};
\t\t\tbuildPhases = (
\t\t\t\t{ios_src} /* Sources */,
\t\t\t\t{ios_fw} /* Frameworks */,
\t\t\t\t{ios_res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = "MinhAgent_iOS";
\t\t\tproductName = "MinhAgent_iOS";
\t\t\tproductReference = {ios_product} /* MinhAgent_iOS.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};''')

mac_target = uid("target:mac")
add(mac_target, f'''{mac_target} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {mac_cfg_list};
\t\t\tbuildPhases = (
\t\t\t\t{mac_src} /* Sources */,
\t\t\t\t{mac_fw} /* Frameworks */,
\t\t\t\t{mac_res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = MinhAgent;
\t\t\tproductName = MinhAgent;
\t\t\tproductReference = {mac_product} /* MinhAgent.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};''')

# Project object
proj_obj = uid("project")
add(proj_obj, f'''{proj_obj} = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = YES;
\t\t\t\tLastSwiftUpdateCheck = 2700;
\t\t\t\tLastUpgradeCheck = 2700;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{ios_target} = {{ CreatedOnToolsVersion = 27.0; }};
\t\t\t\t\t{mac_target} = {{ CreatedOnToolsVersion = 27.0; }};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_cfg_list};
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tproductRefGroup = {products_group} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{ios_target} /* MinhAgent_iOS */,
\t\t\t\t{mac_target} /* MinhAgent */,
\t\t\t);
\t\t}};''')

# Serialize
body = "\n\t\t".join(b for _, b in sorted(objects, key=lambda x: x[0]))
pbxproj = f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 60;
\tobjects = {{
\t\t{body}
\t}};
\trootObject = {proj_obj};
}}
'''

proj_dir = os.path.join(ROOT, "MinhAgent.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write(pbxproj)

print("Wrote", os.path.join(proj_dir, "project.pbxproj"))
print("iOS sources:", len(shared + ios_only), "macOS sources:", len(shared + mac_only))

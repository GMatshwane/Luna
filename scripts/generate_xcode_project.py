#!/usr/bin/env python3
"""Generate Luna.xcodeproj, asset catalog, and app icon."""

from __future__ import annotations

import hashlib
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_SWIFT = [
    "LunaApp.swift",
    "Theme/LunaTheme.swift",
    "Calendar/CalendarDay.swift",
    "Calendar/TaskListOrdering.swift",
    "Calendar/RepeatPolicy.swift",
    "Scores/ScorePolicy.swift",
    "Settings/LunaSettings.swift",
    "Notifications/ReminderPolicy.swift",
    "Notifications/NotificationScheduler.swift",
    "Models/TaskItem.swift",
    "Models/Category.swift",
    "Models/CategoryPolicy.swift",
    "Persistence/LunaPersistence.swift",
    "Services/TaskService.swift",
    "Views/RootView.swift",
    "Views/DayTasksView.swift",
    "Views/DayStripView.swift",
    "Views/CalendarSheet.swift",
    "Views/TaskRowView.swift",
    "Views/EmptyDayView.swift",
    "Views/TaskEditorView.swift",
    "Views/CategoryEditorView.swift",
    "Views/SettingsView.swift",
    "Views/ScoreCardView.swift",
]
TEST_SWIFT = [
    "CalendarDayTests.swift",
    "TaskListOrderingTests.swift",
    "ReminderPolicyTests.swift",
    "RepeatPolicyTests.swift",
    "ScorePolicyTests.swift",
    "CategoryPolicyTests.swift",
]


def uid(name: str) -> str:
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixel) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            r, g, b, *_ = pixel(x, y)
            raw.extend((r, g, b))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def moon_pixel(x: int, y: int) -> tuple[int, int, int, int]:
    # Palette: background #011C40, moon #A7EBF2, glow #54ACBF
    bg = (0x01, 0x1C, 0x40, 255)
    moon = (0xA7, 0xEB, 0xF2, 255)
    glow = (0x54, 0xAC, 0xBF, 255)
    cx = cy = 511.5
    dx = x - cx
    dy = y - cy
    dist = (dx * dx + dy * dy) ** 0.5
    moon_r = 250
    cut_cx, cut_cy, cut_r = cx + 88, cy - 36, 230
    cut = ((x - cut_cx) ** 2 + (y - cut_cy) ** 2) ** 0.5
    if dist <= moon_r and cut > cut_r:
        return moon
    if dist <= moon_r + 28 and cut > cut_r - 12:
        return glow
    # faint stars
    stars = {(180, 160), (820, 210), (760, 780), (240, 820), (900, 520), (140, 500)}
    for sx, sy in stars:
        if (x - sx) ** 2 + (y - sy) ** 2 <= 16:
            return moon
    return bg


def write_assets() -> None:
    catalog = ROOT / "Luna" / "Assets.xcassets"
    iconset = catalog / "AppIcon.appiconset"
    accent = catalog / "AccentColor.colorset"
    iconset.mkdir(parents=True, exist_ok=True)
    accent.mkdir(parents=True, exist_ok=True)

    (catalog / "Contents.json").write_text(
        """{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""",
        encoding="utf-8",
    )
    (iconset / "Contents.json").write_text(
        """{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""",
        encoding="utf-8",
    )
    (accent / "Contents.json").write_text(
        """{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0xF2",
          "green" : "0xEB",
          "red" : "0xA7"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""",
        encoding="utf-8",
    )
    write_png(iconset / "AppIcon.png", 1024, 1024, moon_pixel)


def pbxproj() -> str:
    ids = {
        "project": uid("project"),
        "appTarget": uid("appTarget"),
        "testTarget": uid("testTarget"),
        "appProduct": uid("appProduct"),
        "testProduct": uid("testProduct"),
        "mainGroup": uid("mainGroup"),
        "appGroup": uid("appGroup"),
        "testGroup": uid("testGroup"),
        "productsGroup": uid("productsGroup"),
        "themeGroup": uid("themeGroup"),
        "calendarGroup": uid("calendarGroup"),
        "scoresGroup": uid("scoresGroup"),
        "settingsGroup": uid("settingsGroup"),
        "notificationsGroup": uid("notificationsGroup"),
        "modelsGroup": uid("modelsGroup"),
        "persistenceGroup": uid("persistenceGroup"),
        "servicesGroup": uid("servicesGroup"),
        "viewsGroup": uid("viewsGroup"),
        "appSources": uid("appSources"),
        "appResources": uid("appResources"),
        "appFrameworks": uid("appFrameworks"),
        "testSources": uid("testSources"),
        "testFrameworks": uid("testFrameworks"),
        "appConfigList": uid("appConfigList"),
        "testConfigList": uid("testConfigList"),
        "projectConfigList": uid("projectConfigList"),
        "appDebug": uid("appDebug"),
        "appRelease": uid("appRelease"),
        "testDebug": uid("testDebug"),
        "testRelease": uid("testRelease"),
        "projectDebug": uid("projectDebug"),
        "projectRelease": uid("projectRelease"),
        "assets": uid("assets"),
        "assetsBuild": uid("assetsBuild"),
        "proxy": uid("proxy"),
        "dependency": uid("dependency"),
    }

    file_ids = {}
    build_ids = {}
    for path in APP_SWIFT:
        file_ids[path] = uid("file:" + path)
        build_ids[path] = uid("build:" + path)
    test_file_ids = {}
    test_build_ids = {}
    for path in TEST_SWIFT:
        test_file_ids[path] = uid("tfile:" + path)
        test_build_ids[path] = uid("tbuild:" + path)

    def children(paths, lookup):
        return "\n".join(f"\t\t\t\t{lookup[p]} /* {p.split('/')[-1]} */," for p in paths)

    app_root_files = [p for p in APP_SWIFT if "/" not in p]
    grouped = {
        "Theme": [p for p in APP_SWIFT if p.startswith("Theme/")],
        "Calendar": [p for p in APP_SWIFT if p.startswith("Calendar/")],
        "Scores": [p for p in APP_SWIFT if p.startswith("Scores/")],
        "Settings": [p for p in APP_SWIFT if p.startswith("Settings/")],
        "Notifications": [p for p in APP_SWIFT if p.startswith("Notifications/")],
        "Models": [p for p in APP_SWIFT if p.startswith("Models/")],
        "Persistence": [p for p in APP_SWIFT if p.startswith("Persistence/")],
        "Services": [p for p in APP_SWIFT if p.startswith("Services/")],
        "Views": [p for p in APP_SWIFT if p.startswith("Views/")],
    }
    group_id = {
        "Theme": ids["themeGroup"],
        "Calendar": ids["calendarGroup"],
        "Scores": ids["scoresGroup"],
        "Settings": ids["settingsGroup"],
        "Notifications": ids["notificationsGroup"],
        "Models": ids["modelsGroup"],
        "Persistence": ids["persistenceGroup"],
        "Services": ids["servicesGroup"],
        "Views": ids["viewsGroup"],
    }

    build_files = []
    for path in APP_SWIFT:
        name = path.split("/")[-1]
        build_files.append(
            f"\t\t{build_ids[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};"
        )
    build_files.append(
        f"\t\t{ids['assetsBuild']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ids['assets']} /* Assets.xcassets */; }};"
    )
    for path in TEST_SWIFT:
        build_files.append(
            f"\t\t{test_build_ids[path]} /* {path} in Sources */ = {{isa = PBXBuildFile; fileRef = {test_file_ids[path]} /* {path} */; }};"
        )

    file_refs = []
    file_refs.append(
        f"\t\t{ids['appProduct']} /* Luna.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Luna.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    file_refs.append(
        f"\t\t{ids['testProduct']} /* LunaTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = LunaTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    file_refs.append(
        f"\t\t{ids['assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};"
    )
    for path in APP_SWIFT:
        name = path.split("/")[-1]
        file_refs.append(
            f"\t\t{file_ids[path]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
        )
    for path in TEST_SWIFT:
        file_refs.append(
            f"\t\t{test_file_ids[path]} /* {path} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {path}; sourceTree = \"<group>\"; }};"
        )

    groups = []
    groups.append(
        f"""\t\t{ids['mainGroup']} = {{
			isa = PBXGroup;
			children = (
				{ids['appGroup']} /* Luna */,
				{ids['testGroup']} /* LunaTests */,
				{ids['productsGroup']} /* Products */,
			);
			sourceTree = "<group>";
		}};"""
    )
    app_children = [
        f"\t\t\t\t{file_ids[p]} /* {p.split('/')[-1]} */," for p in app_root_files
    ] + [
        f"\t\t\t\t{group_id[name]} /* {name} */," for name in grouped
    ] + [
        f"\t\t\t\t{ids['assets']} /* Assets.xcassets */,"
    ]
    groups.append(
        f"""\t\t{ids['appGroup']} /* Luna */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(app_children)}
			);
			path = Luna;
			sourceTree = "<group>";
		}};"""
    )
    for name, paths in grouped.items():
        groups.append(
            f"""\t\t{group_id[name]} /* {name} */ = {{
			isa = PBXGroup;
			children = (
{children(paths, file_ids)}
			);
			path = {name};
			sourceTree = "<group>";
		}};"""
    )
    groups.append(
        f"""\t\t{ids['testGroup']} /* LunaTests */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(f"				{test_file_ids[p]} /* {p} */," for p in TEST_SWIFT)}
			);
			path = LunaTests;
			sourceTree = "<group>";
		}};"""
    )
    groups.append(
        f"""\t\t{ids['productsGroup']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids['appProduct']} /* Luna.app */,
				{ids['testProduct']} /* LunaTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};"""
    )

    app_source_files = "\n".join(
        f"\t\t\t\t{build_ids[p]} /* {p.split('/')[-1]} in Sources */," for p in APP_SWIFT
    )
    test_source_files = "\n".join(
        f"\t\t\t\t{test_build_ids[p]} /* {p} in Sources */," for p in TEST_SWIFT
    )

    project_debug = r"""
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
"""

    project_release = r"""
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
"""

    app_settings = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Luna;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UIUserInterfaceStyle = Dark;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.gmatshwane.Luna;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_STRICT_CONCURRENCY = targeted;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

    test_settings = """
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.gmatshwane.LunaTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_STRICT_CONCURRENCY = targeted;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Luna.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Luna";
				TEST_TARGET_NAME = Luna;
"""

    text = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		{ids['proxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids['project']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids['appTarget']};
			remoteInfo = Luna;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{ids['appFrameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['testFrameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{ids['appTarget']} /* Luna */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['appConfigList']} /* Build configuration list for PBXNativeTarget "Luna" */;
			buildPhases = (
				{ids['appSources']} /* Sources */,
				{ids['appFrameworks']} /* Frameworks */,
				{ids['appResources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Luna;
			productName = Luna;
			productReference = {ids['appProduct']} /* Luna.app */;
			productType = "com.apple.product-type.application";
		}};
		{ids['testTarget']} /* LunaTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['testConfigList']} /* Build configuration list for PBXNativeTarget "LunaTests" */;
			buildPhases = (
				{ids['testSources']} /* Sources */,
				{ids['testFrameworks']} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				{ids['dependency']} /* PBXTargetDependency */,
			);
			name = LunaTests;
			productName = LunaTests;
			productReference = {ids['testProduct']} /* LunaTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{ids['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1540;
				LastUpgradeCheck = 1540;
				ORGANIZATIONNAME = Luna;
				TargetAttributes = {{
					{ids['appTarget']} = {{
						CreatedOnToolsVersion = 15.4;
					}};
					{ids['testTarget']} = {{
						CreatedOnToolsVersion = 15.4;
						TestTargetID = {ids['appTarget']};
					}};
				}};
			}};
			buildConfigurationList = {ids['projectConfigList']} /* Build configuration list for PBXProject "Luna" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {ids['mainGroup']};
			productRefGroup = {ids['productsGroup']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids['appTarget']} /* Luna */,
				{ids['testTarget']} /* LunaTests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{ids['appResources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids['assetsBuild']} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{ids['appSources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{app_source_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['testSources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{test_source_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{ids['dependency']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids['appTarget']} /* Luna */;
			targetProxy = {ids['proxy']} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		{ids['projectDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{project_debug}			}};
			name = Debug;
		}};
		{ids['projectRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{project_release}			}};
			name = Release;
		}};
		{ids['appDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{app_settings}			}};
			name = Debug;
		}};
		{ids['appRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{app_settings}			}};
			name = Release;
		}};
		{ids['testDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{test_settings}			}};
			name = Debug;
		}};
		{ids['testRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{test_settings}			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{ids['projectConfigList']} /* Build configuration list for PBXProject "Luna" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['projectDebug']} /* Debug */,
				{ids['projectRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['appConfigList']} /* Build configuration list for PBXNativeTarget "Luna" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['appDebug']} /* Debug */,
				{ids['appRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['testConfigList']} /* Build configuration list for PBXNativeTarget "LunaTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['testDebug']} /* Debug */,
				{ids['testRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {ids['project']} /* Project object */;
}}
"""
    # Fix typo introduced above
    return text, ids


def write_scheme(ids: dict[str, str]) -> None:
    scheme_dir = ROOT / "Luna.xcodeproj" / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / "Luna.xcscheme").write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1540"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['appTarget']}"
               BuildableName = "Luna.app"
               BlueprintName = "Luna"
               ReferencedContainer = "container:Luna.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['testTarget']}"
               BuildableName = "LunaTests.xctest"
               BlueprintName = "LunaTests"
               ReferencedContainer = "container:Luna.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['appTarget']}"
            BuildableName = "Luna.app"
            BlueprintName = "Luna"
            ReferencedContainer = "container:Luna.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['appTarget']}"
            BuildableName = "Luna.app"
            BlueprintName = "Luna"
            ReferencedContainer = "container:Luna.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""",
        encoding="utf-8",
    )


def write_workspace() -> None:
    path = ROOT / "Luna.xcodeproj" / "project.xcworkspace"
    path.mkdir(parents=True, exist_ok=True)
    (path / "contents.xcworkspacedata").write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
        encoding="utf-8",
    )
    xcshared = path / "xcshareddata"
    xcshared.mkdir(exist_ok=True)
    (xcshared / "IDEWorkspaceChecks.plist").write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>IDEDidComputeMac32BitWarning</key>
	<true/>
</dict>
</plist>
""",
        encoding="utf-8",
    )


def main() -> None:
    write_assets()
    text, ids = pbxproj()
    proj = ROOT / "Luna.xcodeproj"
    proj.mkdir(parents=True, exist_ok=True)
    (proj / "project.pbxproj").write_text(text, encoding="utf-8")
    write_scheme(ids)
    write_workspace()
    print("Wrote Luna.xcodeproj, assets, and scheme")


if __name__ == "__main__":
    main()

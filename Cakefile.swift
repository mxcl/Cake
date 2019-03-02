import Cakefile

dependencies = [
    .cake(~>Version(1,0,0, prereleaseIdentifiers: ["debug"])),
    .github("Weebly/OrderedSet" ~> 3.1),
    .github("mxcl/PromiseKit" ~> 6.8),
    .github("mxcl/Path.swift" ~> 0.13),
    .github("PromiseKit/Foundation" ~> 3),
    .github("tuist/xcodeproj" ~> 6.5),
    .github("mxcl/LegibleError" ~> 1),
    .github("mxcl/Version" ~> 1),
    .github("soffes/HotKey" ~> 0.1),
    .github("mxcl/AppUpdater" ~> 1.0),
]

options.suppressDependencyWarnings = true  // this is the default

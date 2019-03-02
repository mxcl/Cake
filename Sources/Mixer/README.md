Mixer is an independent Swift-Package because it builds its own copy
of SwiftPM (since libSwiftPM is not usable from an Xcode installation)
and 1. Cake cannot support c-packages yet; 2. adding SwiftPM as a
dependency kills clean builds (which we intend to fix); and 3. this
would be inefficient since we only need libSwiftPM for Mixer so really
we need Cake to support this more advanced use-case.

We have a subfolder `Base` that contains symlinks to our Cake base
module swift files. This is due to SwiftPM refusing to create modules
for directories that are below the `Package.swift` directory.

# Getting an Xcodeproj

In this directory:

    swift package generate-xcodeproj --xcconfig-overrides .build/libSwiftPM.xcconfig

# Building Cake

Bootstrapping SwiftPM requires `ninja`:

    brew install ninja
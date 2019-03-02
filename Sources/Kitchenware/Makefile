.PHONY: all

BUILD_DIR = $(OUTDIR)/swift-pm/$(CONFIGURATION)
CONFIGURATION = release
outputs = $(OUTDIR)/lib/pm/4/libPackageDescription.dylib $(OUTDIR)/lib/pm/4_2/libPackageDescription.dylib $(OUTDIR)/lib/Cakefile.swiftmodule $(OUTDIR)/lib/Cakefile.swiftdoc $(OUTDIR)/lib/libCakefile.dylib $(OUTDIR)/lib/Version.swiftmodule $(OUTDIR)/lib/Version.swiftdoc
swift_build_outputs = $(BUILD_DIR)/Cakefile.swiftmodule $(BUILD_DIR)/Cakefile.swiftdoc $(BUILD_DIR)/libCakefile.a $(BUILD_DIR)/Version.swiftmodule $(BUILD_DIR)/Version.swiftdoc

all: $(outputs)

$(OUTDIR)/lib:
	mkdir -p $@
$(OUTDIR)/lib/pm/4:
	mkdir -p $@
$(OUTDIR)/lib/pm/4_2:
	mkdir -p $@

$(swift_build_outputs): $(wildcard Sources/Cakefile/*.swift)
	swift build --configuration $(CONFIGURATION) --build-path $(OUTDIR)/swift-pm

$(OUTDIR)/lib/pm/4_2/libPackageDescription.dylib: $(wildcard Sources/PackageDescription/*.swift) | $(OUTDIR)/lib/pm/4_2
	swiftc $^ -emit-library -o $@ -emit-module -module-name PackageDescription -target x86_64-apple-macosx10.10 -suppress-warnings -DPACKAGE_DESCRIPTION_4_2

$(OUTDIR)/lib/pm/4/libPackageDescription.dylib: $(wildcard Sources/PackageDescription/*.swift) | $(OUTDIR)/lib/pm/4
	swiftc $^ -emit-library -o $@ -emit-module -module-name PackageDescription -target x86_64-apple-macosx10.10 -suppress-warnings -DPACKAGE_DESCRIPTION_4

$(OUTDIR)/lib/libCakefile.dylib: $(BUILD_DIR)/libCakefile.a | $(OUTDIR)/lib
	swiftc -Xlinker -dylib -o $@ -Xlinker -all_load $< -target x86_64-apple-macosx10.10
$(OUTDIR)/lib/Cakefile.swiftmodule: $(BUILD_DIR)/Cakefile.swiftmodule | $(OUTDIR)/lib
	cp $< $@
$(OUTDIR)/lib/Cakefile.swiftdoc: $(BUILD_DIR)/Cakefile.swiftdoc | $(OUTDIR)/lib
	cp $< $@
$(OUTDIR)/lib/Version.swiftmodule: $(BUILD_DIR)/Version.swiftmodule | $(OUTDIR)/lib
	cp $< $@
$(OUTDIR)/lib/Version.swiftdoc: $(BUILD_DIR)/Version.swiftdoc | $(OUTDIR)/lib
	cp $< $@

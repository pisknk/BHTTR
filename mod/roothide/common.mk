# common.mk module fragment — included at the end of theos' common.mk.
#
# theos qualifies its framework/library search paths by package scheme:
#   $(THEOS_VENDOR_LIBRARY_PATH)/$(THEOS_TARGET_NAME)/$(THEOS_PACKAGE_SCHEME)
# but theos/lib only ships them for rootless (vendor/lib/iphone/rootless).
# With THEOS_PACKAGE_SCHEME=roothide the -F paths would point at nonexistent
# vendor/lib/iphone/roothide and framework-style includes such as
# <CydiaSubstrate/CydiaSubstrate.h> would fail to compile.
#
# Roothide uses the same /var/jb layout as rootless (same prefixes in the
# .tbd stubs), so reuse the rootless copies for both compiling and linking.
# _THEOS_INTERNAL_CFLAGS/_LDFLAGS expand this list recursively at use time,
# so appending here takes effect for every compile/link rule.
_THEOS_INTERNAL_SEARCHPATHS += \
	$(THEOS_VENDOR_LIBRARY_PATH)/$(THEOS_TARGET_NAME)/rootless \
	$(THEOS_LIBRARY_PATH)/$(THEOS_TARGET_NAME)/rootless

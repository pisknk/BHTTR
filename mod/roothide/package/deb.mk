# Roothide debs are distinguished from rootless debs purely by the
# iphoneos-arm64e architecture label (mirrors theos' rootless deb.mk).
ifneq ($(THEOS_PACKAGE_ARCH),iphoneos-arm64e)
	THEOS_PACKAGE_ARCH := iphoneos-arm64e
endif

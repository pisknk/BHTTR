# roothide package scheme module for mainline theos.
# Ported from theos' bundled rootless module (vendor/mod/rootless) — mainline
# theos ships no roothide scheme, so this repo provides one. Loaded when
# THEOS_PACKAGE_SCHEME=roothide and THEOS_MODULE_PATH=<repo>/mod are passed.
# Roothide Bootstrap uses the same /var/jb prefix as rootless jailbreaks.
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

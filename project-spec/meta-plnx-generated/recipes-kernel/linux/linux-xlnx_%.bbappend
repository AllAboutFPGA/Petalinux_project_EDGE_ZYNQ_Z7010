
FILESEXTRAPATHS_prepend := "${THISDIR}/configs:"
RDEPENDS_${KERNEL_PACKAGE_NAME}-base = ""
KERNEL_CONFIG_COMMAND = ""
do_configure[depends] += "kern-tools-native:do_populate_sysroot"
SRC_URI += "file://plnx_kernel.cfg"
do_configure_append () {
	merge_config.sh -m ${B}/.config ${@" ".join(find_sccs(d))}
	oe_runmake -C ${S} O=${B} oldconfig
}
do_deploy_append () {
	install -m 0644 ${D}/boot/System.map-${KERNEL_VERSION} ${DEPLOYDIR}/System.map.linux
}

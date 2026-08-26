# Guest ADB finding

The public `jqssun/android-lineage-qemu` release documentation states that when ADB is unavailable, the UTM guest must be booted into **LineageOS Recovery**. In Recovery, open **Advanced**, choose **Mount/unmount system**, then choose **Enable ADB**. The same instructions mention removing `/mnt/vendor/_persist/grubenv_abootctrl` from an ADB shell for a related slot-suffix issue. The project will use only the documented `Enable ADB` action; it will not bypass signatures, patch proprietary apps, or alter iPadOS security controls.

Source: https://github.com/jqssun/android-lineage-qemu/releases

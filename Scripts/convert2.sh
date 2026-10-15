sudo apt install android-sdk-libsparse-utils
ver="v0.3.2"
curl -L -o ./AmlImg https://github.com/rmoyulong/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64
chmod +x ./AmlImg
curl -L -o ./uboot.img https://github.com/rmoyulong/u-boot-onecloud/releases/download/Onecloud_Uboot_23.12.24_18.15.09/eMMC.burn.img
./AmlImg unpack ./uboot.img burn/

gunzip openwrt/bin/targets/*/*/*.gz
diskimg=$(ls openwrt/bin/targets/*/*/*.img)
loop=$(sudo losetup --find --show --partscan $diskimg)
img_ext="openwrt.img"
img_mnt="xd"
rootfs_mnt="img"
boot_img=${img_ext}
boot_img_mnt=${img_mnt}
rootfs_img_mnt=${rootfs_mnt}
echo ${boot_img}
echo ${boot_img_mnt}
echo ${rootfs_img_mnt}
sudo rm -rf ${boot_img}
sudo rm -rf ${boot_img_mnt}
sudo rm -rf ${rootfs_img_mnt}
# rootfs 镜像大小必须 <= eMMC 分区表里 rootfs 分区的大小，并且要尽量小：
# USB Burning Tool 在写完后会让设备端回算 rootfs 分区的 sha1，分区越大耗时越长，
# 超过工具约 150s 的读数超时就会报 [0x30403003] / actlen=-116（表现为卡在 95%~97%）。
# 原来写死 2000M，校验约 140s+ 必超时；800M 与 CONFIG_TARGET_ROOTFS_PARTSIZE=800 对齐，
# 校验时间降到 ~60s。ROOTFS_PARTSIZE 若要调大，这里必须同步调大。
ROOTFS_MB=800
sudo dd if=/dev/zero of=${boot_img} bs=1M count=${ROOTFS_MB}
sudo mkfs.ext4 ${boot_img}
sudo mkdir ${boot_img_mnt}
sudo mkdir ${rootfs_img_mnt}
sudo mount ${boot_img} ${boot_img_mnt}
sudo mount ${loop}p2 ${rootfs_img_mnt}
# 用 cp -a 而不是 cp -r：保留符号链接（busybox 的几百个 /bin/* 链接），
# 否则每个链接都会被展开成一份实体 busybox，rootfs 体积翻倍、设备端校验更久。
sudo cp -a ${rootfs_img_mnt}/. ${boot_img_mnt}/ \
  || { echo "rootfs 拷贝失败：${ROOTFS_MB}M 镜像装不下，请调大 ROOTFS_MB"; exit 1; }
sudo sync
echo "--- rootfs 实际占用 / 镜像可用 ---"
sudo du -sm ${boot_img_mnt} 2>/dev/null || true
df -h ${boot_img} 2>/dev/null || true
sudo umount ${boot_img_mnt}
sudo umount ${rootfs_img_mnt}
sudo img2simg ${loop}p1 burn/boot.simg
sudo img2simg openwrt.img burn/rootfs.simg
sudo rm -rf *.img
sudo losetup -d $loop
cat <<EOF >>burn/commands.txt
PARTITION:boot:sparse:boot.simg
PARTITION:rootfs:sparse:rootfs.simg
EOF
prefix=$(ls openwrt/bin/targets/*/*/*.img | sed 's/\.img$//')
burnimg=${prefix}.burn.img
./AmlImg pack $burnimg burn/
for f in openwrt/bin/targets/*/*/*.burn.img; do
  sha256sum "$f" >"${f}.sha"
  xz -9 --threads=0 --compress "$f"
done
sudo rm -rf openwrt/bin/targets/*/*/*.img
sudo rm -rf openwrt/bin/targets/*/*/*.gz
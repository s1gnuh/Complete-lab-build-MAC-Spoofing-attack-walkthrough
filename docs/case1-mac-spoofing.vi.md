# Case 1 — MAC Spoofing (giả mạo danh tính)

[English](case1-mac-spoofing.md) · **Tiếng Việt**

> Tài liệu đồng hành với lab trong repo này, soạn sẵn để đưa vào **Chương 3 — Triển khai & Thực nghiệm**
> (mục **3.3.1**) của báo cáo. Nội dung gồm: mục tiêu, cơ chế, đặc trưng tấn công, quy trình thực hiện
> kèm bằng chứng Before/Attack/After, bảng tổng hợp và kết luận.
>
> Môi trường: GNS3 + Kali Linux + Open vSwitch (`br0`), mạng phẳng `192.168.10.0/24`, **cô lập hoàn toàn,
> không nối Internet / mạng thật**. Tham khảo lý thuyết nền ở [huong-dan-viet-bao-cao.md](huong-dan-viet-bao-cao.md).

---

## 1. Mục tiêu

Máy tấn công **Kali** đổi địa chỉ MAC của mình thành MAC của **victim (PC1)**. Vì switch (Open vSwitch)
học và chuyển khung dựa trên trường **Source MAC** mà **không xác thực**, nó sẽ nhầm lẫn danh tính:
một MAC xuất hiện trên hai cổng, và lưu lượng đáng lẽ gửi cho victim có thể bị chuyển về Kali.

Đây là dạng cơ bản nhất của tấn công Layer-2, khai thác đúng một câu: *"Ethernet/switch tin tưởng trường
Source MAC mà không kiểm chứng."*

## 2. Đặc trưng tấn công (6 tiêu chí)

| Tiêu chí | Nội dung |
|---|---|
| **(a) Mục tiêu** | Mạo danh host khác để **vượt lọc MAC** (MAC allowlist), né kiểm toán/truy vết, hoặc chiếm danh tính đã được cấp quyền. |
| **(b) Cơ chế** | Đổi Source MAC của card mạng thành MAC của victim bằng `macchanger -m` / `ip link set ... address`. |
| **(c) Điều kiện** | Cùng phân đoạn **Layer 2**; biết trước MAC hợp lệ cần mạo danh. |
| **(d) Tác động (CIA)** | Chủ yếu **Confidentiality / Authorization** (truy cập trái phép, vượt kiểm soát). Nếu victim vẫn online → gây **MAC flapping**, ảnh hưởng **Availability** (mạng bất ổn). |
| **(e) Dấu hiệu** | Một MAC xuất hiện trên **hai cổng**; MAC "nhảy" qua lại giữa các cổng; bit U/L = Local (dấu hiệu MAC bị đặt thủ công). |
| **(f) Công cụ** | `macchanger`, `ip link set ... address`. |

## 3. Chuẩn bị — đưa về trạng thái sạch

Trên **Kali**, khôi phục MAC thật trước khi bắt đầu để baseline chính xác:

```bash
sudo ip link set eth0 down
sudo macchanger -p eth0
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
```

> **Lưu ý tên card mạng:** các lệnh dùng `eth0`; Ubuntu/Kali mới có thể đặt tên `ens33` / `enp0s3`.
> Chạy `ip link show` trước để lấy đúng tên và thay vào các lệnh.

---

## 4. Phần A — Trạng thái BEFORE (chưa tấn công)

**A1. MAC thật của Kali** — terminal Kali:

```bash
macchanger -s eth0
```
→ **Ảnh 1:** `Current MAC = aa:bb:cc:00:00:50` (MAC đã pin cho attacker).

**A2. Sinh traffic để switch học đúng MAC** — terminal Kali:

```bash
ping -c 2 192.168.10.10
ping -c 2 192.168.10.1
```

**A3. Bảng MAC (FDB) của switch — trạng thái sạch** — console node **OpenvSwitch**:

```bash
ovs-appctl fdb/show br0
```
→ **Ảnh 2:** mỗi MAC nằm trên một cổng riêng (Kali = port 1, PC1 = port 2, PC2 = port 3). Đây là **baseline**.

## 5. Phần B — Thực hiện tấn công

**B1. Mở Wireshark** (terminal Kali thứ 2) để ghi bằng chứng:

```bash
sudo wireshark &
```
Chọn giao diện `eth0` → **Start** → đặt bộ lọc `arp || icmp`.

**B2. Giả MAC của victim** — terminal Kali:

```bash
sudo ip link set eth0 down
sudo macchanger -m 00:50:79:66:68:00 eth0   # MAC của victim (PC1)
sudo ip link set eth0 up
macchanger -s eth0
```
→ **Ảnh 3:** `Current MAC = 00:50:79:66:68:00 (PRIVATE)` — Kali đã mang MAC của victim.

> Giá trị `00:50:79:66:68:00` là MAC thực tế quan sát được của victim trong lab GNS3. Nếu trong mô hình
> của bạn victim được pin MAC ví dụ `aa:bb:cc:00:00:10`, hãy dùng chính giá trị đó. Lấy MAC thật bằng
> `ip link show` trên máy victim.

**B3. Sinh traffic từ Kali (đang mang danh victim):**

```bash
ping -c 3 192.168.10.1
```

## 6. Phần C — Bằng chứng AFTER

**C1. Bảng MAC switch sau tấn công** — console node **OpenvSwitch**:

```bash
ovs-appctl fdb/show br0
```
→ **Ảnh 4:** MAC `00:50:79:66:68:00` giờ nằm trên **port 1** (cổng của Kali) thay vì port 2 — **switch đã bị lừa**,
danh tính của victim bị gắn vào cổng attacker.

**C2. (tùy chọn) Wireshark** → **Ảnh 5:** các khung đi/đến mang MAC của victim được bắt trên card của Kali,
xác nhận Kali nhận được lưu lượng dưới danh nghĩa victim.

## 7. Phần D — Khôi phục (dọn dẹp sau khi chụp xong)

```bash
sudo ip link set eth0 down
sudo macchanger -p eth0
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
ip addr show eth0
```

---

## 8. Bảng tổng hợp bằng chứng (dùng cho báo cáo)

| Mốc | Lệnh | Bằng chứng | Hình |
|---|---|---|---|
| **Before** | `macchanger -s eth0` | MAC Kali = `aa:bb:cc:00:00:50` | Ảnh 1 |
| **Before** | `ovs-appctl fdb/show br0` | MAC victim ở **port 2** | Ảnh 2 |
| **Attack** | `macchanger -m 00:50:79:66:68:00` | MAC Kali đổi thành MAC victim | Ảnh 3 |
| **After** | `ovs-appctl fdb/show br0` | MAC victim **nhảy sang port 1 / Kali** | Ảnh 4 |
| **After** | Wireshark (`arp \|\| icmp`) | Kali bắt traffic dưới danh victim *(tùy chọn)* | Ảnh 5 |

## 9. Kết luận Case 1

Tấn công **thành công**: switch mặc định **không có cơ chế ràng buộc MAC ↔ cổng**, nên tin tưởng mọi
Source MAC mà host khai báo. Kết quả là Kali mạo danh được victim và làm bảng FDB ghi sai cổng của victim
(MAC flapping từ port 2 sang port 1).

Nguyên nhân gốc là **thiếu xác thực trường Source MAC ở Layer 2** — không phải lỗi cấu hình. Vì vậy biện
pháp khắc phục ở phần Phòng thủ sẽ **ràng buộc MAC ↔ port** trên Open vSwitch (tương đương **Port Security**
của Cisco) để chặn chính xác kịch bản này; chi tiết và kết quả chạy lại (tấn công thất bại, đếm `drop`
counter) được trình bày ở mục **3.4**.

---

<sub>Lab MAC Spoofing · Case 1 · dùng trong môi trường ảo cô lập cho mục đích học tập.</sub>

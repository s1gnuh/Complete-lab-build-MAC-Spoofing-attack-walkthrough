# Dựng lab hoàn chỉnh & hướng dẫn tấn công giả mạo MAC

[English](README.md) · **Tiếng Việt**

Lab thực hành dựng một **mạng ảo cô lập** và tái hiện các tấn công Lớp 2 kinh điển trên đó —
kèm biện pháp phòng thủ tương ứng và một bảng ghi kết quả đo lường. Xây trên
**GNS3 + Kali Linux + Open vSwitch**, có phần bổ trợ bằng Cisco **Packet Tracer** để đối chiếu
với chuẩn doanh nghiệp.

Hướng dẫn tương tác đầy đủ nằm trong [`index.html`](index.html) — mở bằng trình duyệt để xem
từng bước, có nút sao chép lệnh, sơ đồ mạng và bảng điền kết quả (nút chuyển VI/EN ở góc trên phải).

Cần viết báo cáo? Xem tài liệu đồng hành trong [`docs/huong-dan-viet-bao-cao.md`](docs/huong-dan-viet-bao-cao.md).

---

## ⚠️ Phạm vi & đạo đức

**Chỉ dùng cho mục đích học tập trong môi trường lab ảo của bạn.** Toàn bộ tấn công chỉ được
thực hiện trên mạng ảo cô lập (GNS3, **không nối Internet hay mạng trường/sản xuất**). Tấn công
vào mạng/thiết bị không được phép là vi phạm pháp luật.

---

## Sơ đồ & địa chỉ

Một mạng phẳng `192.168.10.0/24`. Ba máy cắm vào cùng một switch ảo Open vSwitch (`br0`).

| Máy               | Vai trò            | IP              | MAC (ví dụ)         | Port  |
|-------------------|--------------------|-----------------|---------------------|-------|
| Kali Linux        | tấn công           | `192.168.10.50` | `aa:bb:cc:00:00:50` | port1 |
| Ubuntu / Lubuntu  | nạn nhân           | `192.168.10.10` | `aa:bb:cc:00:00:10` | port2 |
| Ubuntu / Lubuntu  | gateway / server   | `192.168.10.1`  | `aa:bb:cc:00:00:01` | port3 |

> **Lưu ý:** cột MAC là MAC bạn *đặt cố định* cho mỗi máy để dễ viết rule phòng thủ. Ghi lại MAC
> thật bằng `ip link show`, và thay `eth0` trong các script bằng tên card thật của bạn (Ubuntu
> mới thường dùng `ens33` / `enp0s3`).

---

## Phần mềm cần có

| Phần mềm | Dùng để |
|---|---|
| GNS3 + GNS3 VM (VMware) | Nền mô phỏng mạng |
| VMware Workstation / Player | Chạy GNS3 VM và các máy ảo |
| Open vSwitch appliance | Switch L2 (tải miễn phí từ GNS3 Marketplace) |
| Kali Linux (VM) | Máy tấn công |
| Ubuntu / Lubuntu (VM) | Nạn nhân + Gateway (clone 2 bản) |
| Wireshark | Bắt gói, chứng minh kết quả |

**RAM:** lab chạy 4 VM cùng lúc, nên thực tế cần **16 GB**. Với 8 GB, hãy giảm tải (thay 2 VM
Ubuntu bằng Docker appliance của GNS3 hoặc node VPCS). Bật VT-x/AMD-V trong BIOS.

---

## Bắt đầu nhanh

1. Dựng topology trong GNS3 và cài appliance **Open vSwitch** (xem `index.html` → *Cài đặt VM*).
2. Cấu hình từng máy. Các lệnh được đóng gói thành script trong [`scripts/`](scripts/):

   ```bash
   # Trên Kali (máy tấn công)
   sudo ./scripts/setup-kali.sh eth0

   # Trên máy nạn nhân
   sudo ./scripts/setup-victim.sh eth0

   # Trên gateway
   sudo ./scripts/setup-gateway.sh eth0
   ```

   > Thay `eth0` bằng tên card thật lấy từ `ip link show`.

3. Kiểm tra kết nối, sau đó chạy các tấn công **khi chưa bật phòng thủ**, bắt gói bằng Wireshark.
4. Áp dụng phòng thủ trên console OVS và chạy lại từng tấn công để xác nhận nó thất bại:

   ```bash
   # Trên console của node Open vSwitch
   ./scripts/ovs-defense.sh      # thêm rule ràng buộc MAC↔port + IP↔MAC cho ARP
   ./scripts/ovs-reset.sh        # xóa hết rule (về trạng thái "không phòng thủ")
   ```

---

## Ba kịch bản tấn công

| # | Tấn công | Ý tưởng | Công cụ |
|---|--------|------|------|
| 1 | **MAC Spoofing** | Mạo danh MAC của nạn nhân để vượt lọc MAC | `macchanger` |
| 2 | **CAM Table Overflow** | Làm tràn bảng MAC, ép switch hoạt động như hub | `macof` |
| 3 | **ARP + MAC Spoofing (MITM)** | Đầu độc ARP victim↔gateway để chặn bắt lưu lượng | `bettercap` |

> **Giới hạn Case 2:** Open vSwitch có bảng MAC lớn và xử lý khác switch phần cứng, nên `macof`
> có thể không đẩy được OVS sang chế độ "hub" như thiết bị Cisco thật. Nếu không bắt được lưu
> lượng, hãy trình bày Case 2 như một minh họa khái niệm và dồn số liệu chính vào Case 1 & 3.

---

## Phòng thủ

- **Open vSwitch (OpenFlow)** — ràng buộc MAC↔port (chống Case 1 & 2) và IP↔MAC cho ARP
  (chống Case 3). Xem [`scripts/ovs-defense.sh`](scripts/ovs-defense.sh).
- **Cisco Packet Tracer** — bản tương đương chuẩn doanh nghiệp: Port Security, DHCP Snooping
  và Dynamic ARP Inspection. Cấu hình và ghi chú trong `index.html` → *Packet Tracer*.

---

## Tiêu chí đo lường

- Tấn công thành công? (Wireshark có bắt được lưu lượng của nạn nhân không)
- Khung gói độc bị chặn (counter drop trong `ovs-ofctl dump-flows br0`)
- Thời gian phát hiện/chặn (timestamp từ lúc tấn công đến gói bị drop đầu tiên)
- Ảnh hưởng tới lưu lượng hợp lệ (ping victim↔gateway có đứt không — false positive)
- Số MAC giả trong bảng CAM (`ovs-appctl fdb/show br0` trước/sau)

---

## Bố cục kho mã

```
.
├── index.html                      # Hướng dẫn lab tương tác song ngữ đầy đủ
├── scripts/
│   ├── setup-kali.sh               # Máy tấn công: pin MAC + IP tĩnh, cài tool
│   ├── setup-victim.sh             # Nạn nhân: MAC + IP + default route
│   ├── setup-gateway.sh            # Gateway: MAC + IP + ip_forward
│   ├── ovs-defense.sh              # Rule OpenFlow ràng buộc MAC↔port & IP↔MAC cho ARP
│   └── ovs-reset.sh                # Xóa hết flow + các lệnh kiểm tra hữu ích
├── docs/
│   ├── report-writing-guide.md     # Tài liệu đồng hành viết báo cáo (tiếng Anh)
│   └── huong-dan-viet-bao-cao.md   # Tài liệu đồng hành viết báo cáo (tiếng Việt)
├── LICENSE
└── README.md
```

---

<sub>🤖 Generated with [Claude Code](https://claude.com/claude-code)</sub>

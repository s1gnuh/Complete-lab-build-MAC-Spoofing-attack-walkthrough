# Hướng dẫn viết báo cáo — Tấn công giả mạo MAC (MAC Spoofing Attack)

> Tài liệu đồng hành với lab trong repo này. Mục tiêu: giúp bạn viết một bài luận / báo cáo
> đầy đủ **đặc tính chi tiết** của tấn công giả mạo MAC, và nối lý thuyết với số liệu thực nghiệm
> bạn thu được từ `index.html` + `scripts/`.
>
> Cách dùng: đọc Phần I–III để nắm đặc tính cần trình bày, dùng Phần IV làm khung chương mục,
> Phần V để biến số liệu lab thành bảng/biểu trong báo cáo, Phần VI để tránh lỗi thường gặp.
>
> English version: [report-writing-guide.md](report-writing-guide.md)

---

## Phần I — Nền tảng: địa chỉ MAC và tại sao nó bị giả mạo được

### 1.1 Địa chỉ MAC là gì
- MAC (Media Access Control) address: định danh **48 bit** (6 byte), gắn với card mạng (NIC),
  hoạt động ở **Lớp 2 (Data Link)** của mô hình OSI. Ví dụ: `aa:bb:cc:00:00:10`.
- Cấu trúc: 24 bit đầu = **OUI** (Organizationally Unique Identifier, định danh nhà sản xuất),
  24 bit sau = số hiệu NIC. Bit thứ 2 của byte đầu = **U/L** (Universal/Local): khi ta *đặt MAC thủ công*
  thì thường bật bit Local → đây cũng là một dấu hiệu nhận biết MAC bị đổi.
- MAC nằm trong **Ethernet frame** ở hai trường: `Destination MAC` và `Source MAC` (mỗi trường 6 byte),
  đứng trước trường EtherType và payload.

### 1.2 Switch học MAC như thế nào (cơ chế bị khai thác)
- Switch duy trì **bảng CAM / MAC address table** (trên Open vSwitch gọi là **FDB** — Forwarding Database).
- Khi một frame đi vào, switch ghi lại cặp `(Source MAC, port đến)` → *học* vị trí của máy.
- Khi cần chuyển frame: nếu `Destination MAC` đã có trong bảng → gửi đúng 1 port (unicast);
  nếu **chưa biết** (unknown unicast) → **flood** ra mọi port.
- Bảng có giới hạn kích thước và mỗi entry có **thời gian aging** (ví dụ 300 giây).

### 1.3 Lỗ hổng gốc rễ — đặc tính quan trọng nhất phải nêu trong báo cáo
Ethernet/switch **không xác thực trường Source MAC**. Switch tin tuyệt đối vào MAC nguồn mà frame khai báo.
Vì vậy bất kỳ máy nào cũng có thể:
1. **Khai một MAC không phải của mình** (giả mạo danh tính), và
2. **Bơm vô số MAC giả** để phá cơ chế học (làm tràn bảng).

Toàn bộ họ tấn công trong báo cáo đều bắt nguồn từ một câu: *"Lớp 2 tin vào MAC nguồn mà không kiểm chứng."*

---

## Phần II — Phân loại và đặc tính chi tiết của tấn công giả mạo MAC

Trình bày mỗi tấn công theo 6 đặc tính cố định (giúp báo cáo nhất quán và dễ chấm):
**(a) Mục tiêu · (b) Cơ chế · (c) Điều kiện tiên quyết · (d) Tác động (CIA) · (e) Dấu hiệu nhận biết · (f) Công cụ**.

### 2.1 MAC Spoofing thuần — giả mạo danh tính (Lab Case 1)
- **(a) Mục tiêu:** mạo danh một máy khác để **vượt qua lọc MAC** (MAC filtering/allowlist),
  né theo dõi/kiểm toán, hoặc chiếm danh tính đã được cấp quyền.
- **(b) Cơ chế:** đổi Source MAC của NIC thành MAC của nạn nhân (`macchanger -m`).
- **(c) Điều kiện:** cùng **phân đoạn L2**; biết MAC hợp lệ cần mạo danh.
- **(d) Tác động:** chủ yếu **Confidentiality/Authorization** (truy cập trái phép, bypass kiểm soát).
  Nếu nạn nhân còn online → gây **MAC flapping**, ảnh hưởng **Availability** (bất ổn định).
- **(e) Dấu hiệu:** một MAC xuất hiện trên **2 port**; MAC nhảy port liên tục; bit U/L = Local.
- **(f) Công cụ:** `macchanger`, `ip link set ... address`.

### 2.2 MAC Flooding / CAM Table Overflow (Lab Case 2)
- **(a) Mục tiêu:** ép switch về chế độ **fail-open** (như hub) để **nghe lén** traffic của máy khác.
- **(b) Cơ chế:** bơm hàng nghìn frame với Source MAC ngẫu nhiên (`macof`) → bảng CAM đầy →
  switch không học/giữ được entry hợp lệ → frame đến đích "chưa biết" bị **flood** ra mọi port.
- **(c) Điều kiện:** cùng L2; switch có bảng CAM nhỏ, hành vi fail-open.
- **(d) Tác động:** **Confidentiality** (nghe lén) và **Availability** (switch quá tải).
- **(e) Dấu hiệu:** bảng CAM phình bất thường; lượng lớn MAC lạ trong thời gian ngắn.
- **(f) Công cụ:** `macof` (bộ dsniff).
- **⚠️ Đặc tính giới hạn — bắt buộc nêu:** **Open vSwitch** có bảng FDB lớn và không fail-open
  giống switch phần cứng Cisco, nên trên lab này Case 2 thường **không nghe lén được**. Đây không phải
  lỗi của bạn mà là **đặc tính kiến trúc** — hãy trình bày như một *phát hiện thực nghiệm* và là lý do
  cần đối chiếu với Cisco (Packet Tracer).

### 2.3 ARP Spoofing + MAC Spoofing → MITM (Lab Case 3)
- **(a) Mục tiêu:** đứng giữa (Man-in-the-Middle) victim ↔ gateway để **đọc/sửa** mọi lưu lượng.
- **(b) Cơ chế:** gửi **ARP reply giả** để ánh xạ `IP gateway → MAC attacker` trong cache ARP của victim
  (và ngược lại nếu full-duplex). Mọi gói victim gửi "cho gateway" thực ra tới attacker; attacker bật
  `ip_forward` để chuyển tiếp nên victim **không mất mạng** → tấn công âm thầm.
- **(c) Điều kiện:** cùng L2; không có Dynamic ARP Inspection.
- **(d) Tác động:** đủ cả **C-I-A**: nghe lén (C), sửa gói/giả mạo (I), có thể ngắt kết nối (A).
- **(e) Dấu hiệu:** `ip neigh` của victim cho thấy MAC gateway bị thay bằng MAC attacker;
  cùng một MAC gắn với **nhiều IP**; ARP reply không được yêu cầu (gratuitous).
- **(f) Công cụ:** `bettercap` (hoặc `ettercap`, `arpspoof`).

> **Mối liên hệ cần giải thích trong báo cáo:** ARP spoofing là một *hệ quả / dạng nâng cao* của giả mạo
> ở Lớp 2 — nó lợi dụng việc ARP (giao thức ánh xạ IP↔MAC) cũng **không xác thực**. Vì vậy tấn công MAC
> và ARP gắn chặt nhau: kiểm soát MAC (Port Security) chặn 2.1–2.2, kiểm soát ARP (DAI) chặn 2.3.

---

## Phần III — Đặc tính phòng thủ (để viết chương giải pháp)

Trình bày mỗi biện pháp theo: **nguyên lý · chặn case nào · ưu điểm · hạn chế**.

| Biện pháp | Nguyên lý | Chặn | Hạn chế |
|---|---|---|---|
| **Port Security** (Cisco) / **MAC↔port binding** (OVS rule A) | Mỗi port chỉ cho 1 MAC định sẵn, vi phạm → err-disabled/drop | Case 1, 2 | Khó quản ở mạng lớn/di động; không chống ARP giả nếu MAC vẫn hợp lệ |
| **DHCP Snooping** | Lập bảng tin cậy IP↔MAC↔port từ giao dịch DHCP | (nền cho DAI) | Cần host dùng DHCP; nhiều bản Packet Tracer không hỗ trợ |
| **Dynamic ARP Inspection (DAI)** / **ARP IP↔MAC binding** (OVS rule B) | Loại ARP có cặp IP–MAC sai trên port untrusted | Case 3 | Cần binding chuẩn; rule thủ công dễ thiếu `arp_sha`/`in_port` (xem dưới) |
| **802.1X** | Xác thực thiết bị trước khi cho lên mạng | 1, 2, 3 (gốc) | Cần hạ tầng RADIUS; ngoài phạm vi lab |
| **Mã hóa (TLS/VPN)** | Giả định mạng không tin cậy; bảo vệ *nội dung* dù bị MITM | Giảm tác động 3 | Không ngăn tấn công, chỉ giảm thiệt hại → "defense in depth" |

### 3.1 Phân biệt hai loại phòng thủ (điểm nên nhấn trong báo cáo)
- **Phòng ngừa (preventive):** rule OVS tĩnh, Port Security — chặn **tức thời**, không có "thời gian phát hiện".
- **Phát hiện/phản ứng (detective):** arpwatch, IDS cảnh báo MAC trùng/flapping — có độ trễ.

Lab này thuộc nhóm **phòng ngừa**, nên khi báo cáo tiêu chí "thời gian chặn" hãy diễn giải là *chặn ngay từ gói đầu*,
đừng bịa ra "thời gian phát hiện".

### 3.2 Hạn chế của rule OVS mẫu (chất liệu cho phần "Hướng hoàn thiện")
Rule ARP mẫu trong lab chỉ kiểm `dl_src` + `arp_spa`, **chưa kiểm** `in_port` và `arp_sha` (sender-MAC trong
payload ARP). Nó chặn được bettercap mặc định, nhưng attacker tinh vi (đặt `dl_src` = MAC gateway, `arp_sha` =
MAC mình) vẫn có thể lọt. DAI "thật" ràng buộc đồng thời **IP ↔ Ethernet-src ↔ arp_sha ↔ đúng port**.
Nêu điều này cho thấy bạn hiểu sâu, không chỉ chạy theo hướng dẫn.

---

## Phần IV — Khung chương mục đề xuất cho báo cáo

Lab này tương ứng **Chương 3 (Triển khai & Thực nghiệm)**. Khung đầy đủ gợi ý:

- **Chương 1 — Tổng quan**
  - 1.1 Lý do chọn đề tài · 1.2 Mục tiêu & phạm vi · 1.3 Phương pháp nghiên cứu (lab ảo cô lập) · 1.4 Bố cục
- **Chương 2 — Cơ sở lý thuyết** (dựa Phần I–II tài liệu này)
  - 2.1 Mô hình OSI & Lớp 2, Ethernet frame, địa chỉ MAC
  - 2.2 Cơ chế học MAC của switch (CAM/FDB)
  - 2.3 Lỗ hổng gốc: không xác thực Source MAC
  - 2.4 Phân loại tấn công: MAC spoofing, CAM overflow, ARP+MAC MITM
  - 2.5 Tổng quan các biện pháp phòng thủ (Phần III)
- **Chương 3 — Triển khai & Thực nghiệm** (chính là lab này)
  - 3.1 Thiết kế mô hình mạng (topology, bảng địa chỉ — chèn sơ đồ + ảnh GNS3)
  - 3.2 Dựng môi trường (GNS3 + Kali + OVS; cấu hình từng máy; kết quả ping nền)
  - 3.3 Thực hiện tấn công (Case 1–3, kèm ảnh Wireshark/`ip neigh`/`fdb-show`)
  - 3.4 Triển khai phòng thủ trên OVS và chạy lại để kiểm chứng
  - 3.5 Đối chiếu chuẩn doanh nghiệp bằng Cisco Packet Tracer (Port Security, DAI)
  - 3.6 Kết quả đo lường (bảng so sánh trước/sau — xem Phần V)
- **Chương 4 — Đánh giá & Thảo luận**
  - 4.1 Phân tích kết quả · 4.2 Hạn chế (OVS vs Cisco ở Case 2; lỗ hổng rule ARP) · 4.3 Hướng hoàn thiện
- **Chương 5 — Kết luận**

> Nếu đề bài là "bài luận" ngắn thay vì đồ án, gộp thành: *Mở đầu → Lý thuyết → Thực nghiệm (demo) →
> Phòng thủ → Kết luận*, giữ nguyên tinh thần các phần trên.

---

## Phần V — Biến số liệu lab thành kết quả trong báo cáo

### 5.1 Bảng kết quả chính (mẫu điền từ worksheet trong `index.html`)

| Case | Không phòng thủ | Có phòng thủ (OVS) | Bằng chứng |
|---|---|---|---|
| 1 — MAC Spoofing | Thành công / bypass lọc MAC | Bị drop tại switch | `dump-flows` drop counter; ảnh `fdb/show` |
| 2 — CAM Overflow | *(OVS: không fail-open — demo khái niệm)* | N/A | Số entry `fdb/show` trước/sau |
| 3 — ARP MITM | MITM thành công, bắt được traffic | ARP giả bị loại | `ip neigh` victim trước/sau; log bettercap |

### 5.2 Năm tiêu chí đo lường (đã có trong lab) và cách lấy số
1. **Tấn công thành công?** — Wireshark có bắt được traffic victim không (có/không + ảnh).
2. **Tỉ lệ/khối lượng gói độc bị chặn** — `ovs-ofctl dump-flows br0`, đọc `n_packets` của rule drop.
3. **Thời điểm chặn** — rule cài sẵn ⇒ chặn ngay gói đầu (diễn giải là *phòng ngừa*, xem 3.1).
4. **Ảnh hưởng traffic hợp lệ (false positive)** — ping victim↔gateway có đứt không khi bật phòng thủ.
5. **Số MAC giả trong CAM** — `ovs-appctl fdb/show br0` đếm entry trước/sau tấn công.

### 5.3 Ảnh chụp bắt buộc (gom sẵn để chèn báo cáo)
- Topology GNS3 + kết quả 3 lệnh ping nền (mục 3.1–3.2).
- Mỗi Case: trạng thái **trước** (no-defense, tấn công thành công) và **sau** (defense-on, bị chặn).
- `dump-flows` với drop counter tăng; `fdb/show` trước/sau; `ip neigh` victim trước/sau (Case 3).
- Packet Tracer: port chuyển **err-disabled** sau khi spoof MAC (mục 3.5).

---

## Phần VI — Checklist & lỗi thường gặp (để không mất điểm)

**Checklist nộp bài**
- [ ] Nêu rõ **lỗ hổng gốc** (không xác thực Source MAC) — đừng chỉ liệt kê công cụ.
- [ ] Mỗi tấn công trình bày đủ 6 đặc tính (a–f ở Phần II).
- [ ] Mỗi kết quả có **bằng chứng ảnh**, chú thích rõ "trước/sau", "no-defense/defense-on".
- [ ] Trình bày trung thực giới hạn Case 2 trên OVS như một **phát hiện**, không giấu.
- [ ] Có phần **đối chiếu Cisco** (3.5) để chứng minh giải pháp tương đương chuẩn doanh nghiệp.
- [ ] Phần hạn chế nêu được lỗ hổng rule ARP (thiếu `arp_sha`/`in_port`) — điểm cộng chiều sâu.
- [ ] Trích dẫn nguồn (xem dưới).

**Lỗi thường gặp**
- Nhầm Lớp 2 (MAC) với Lớp 3 (IP); nhầm ARP spoofing là "tấn công IP".
- Coi `macof` chắc chắn thành công trên OVS → sai kỳ vọng, mất thời gian.
- Quên NetworkManager ghi đè MAC/IP → tưởng lệnh sai (tắt NetworkManager trước khi pin).
- Quên thay `in_port=1/2/3` bằng số port thật từ `ovs-ofctl show br0` → phòng thủ "không chạy".
- Gọi phòng thủ tĩnh là "phát hiện" thay vì "phòng ngừa".
- Chỉ dán lệnh, thiếu **giải thích cơ chế** và **phân tích số liệu**.

**Gợi ý nguồn trích dẫn**
- IEEE 802.1D / 802.1Q (bridging, VLAN); IEEE 802.1X (xác thực cổng).
- RFC 826 (ARP).
- Tài liệu Cisco: Port Security, DHCP Snooping, Dynamic ARP Inspection.
- Tài liệu Open vSwitch: `ovs-ofctl`, OpenFlow fields (`arp_spa`, `arp_sha`, `dl_src`).
- Man pages: `macchanger`, `macof`(dsniff), `bettercap`.

---

<sub>Tài liệu đồng hành lab MAC Spoofing · dùng cho mục đích học tập trong môi trường ảo cô lập.</sub>

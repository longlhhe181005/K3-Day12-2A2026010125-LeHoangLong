# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng ` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: ..........................  Mã học viên: ..........................

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> *khi quên tạo agent_api_key và set variable cho nó, /ready và /ask sẽ báo lỗi 500. Nếu agent_api_key mà có giá trị mặc định là "changeme", app vẫn chạy bình thường.Nhưng đây là cấu hình không an toàn vì nếu có người biết được khóa mặc định "changeme" thì cũng gọi được /ask free, tiêu vào ngân sách LLM mà dev khong biết cho tới khi nhận được cảnh báo*

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật lấy được khi gọi `/ask`:
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T05:35:25.786987+00:00", "user_id": "sv-stats-test", "tokens_in": 1, "tokens_out": 33, "cost_usd": 1.995e-05}
> ```
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> 1. Lọc/truy vấn theo từng trường: ví dụ `jq 'select(.cost_usd > 0.00002)'` hoặc trên Datadog/Grafana lọc theo `user_id="sv-stats-test"` — vì mỗi field là một key riêng, máy parse được ngay, không cần regex đoán mò trong câu tiếng Việt tự do như `print()`.
> 2. Tổng hợp/tính toán tự động: cộng dồn `cost_usd` theo `user_id` để biết ai tốn tiền nhất trong ngày, hoặc dựng alert "nếu `cost_usd` trung bình > X thì báo" — `print()` không có cấu trúc key/value nên không thể tổng hợp bằng máy được, chỉ đọc được bằng mắt người.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ... MB |
| Multi-stage | ... MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Số đo thật (build bằng `docker build` + `docker images`):
>
> | Bản | Dung lượng |
> |-----|-----------|
> | 1 stage (`python:3.11` đầy đủ) | 1.73 GB |
> | Multi-stage (`python:3.11-slim`) | 270 MB |
>
> Chênh lệch ~1.46GB đó chủ yếu là: (1) base image `python:3.11` đầy đủ chứa toàn bộ toolchain build (gcc, make, các thư viện dev) mà `python:3.11-slim` không có — những thứ này chỉ cần lúc `pip install` biên dịch package, không cần lúc chạy app; (2) bản 1-stage giữ nguyên pip cache và cả những file không liên quan (`.git`, `tests/`, `screenshots/`...) vì `COPY . .` chép toàn bộ thư mục, trong khi multi-stage chỉ `COPY --from=builder /install /usr/local` (đúng gói đã cài) rồi `COPY app/ utils/` (đúng code cần chạy) sang stage runtime sạch.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Dockerfile hiện tại: `COPY requirements.txt .` → `RUN pip install ...` (ở stage `builder`) → sau đó mới `COPY app/ app/` và `COPY utils/ utils/` (ở stage runtime). Nếu chỉ sửa 1 ký tự trong `app/main.py` rồi build lại: layer `COPY requirements.txt .` và `RUN pip install` ở stage `builder` được dùng lại từ cache (vì `requirements.txt` không đổi), chỉ layer `COPY app/ app/` trở đi phải chạy lại. Nếu đặt `COPY . .` lên trước `RUN pip install` thì Docker tính hash của layer `COPY` dựa trên toàn bộ nội dung thư mục — sửa 1 dòng code làm hash đó đổi, kéo theo `RUN pip install` (đứng sau) mất cache và phải cài lại toàn bộ dependency từ đầu, dù `requirements.txt` không hề thay đổi.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: (1) code Python có lỗ hổng, ví dụ endpoint nhận input không kiểm soát dẫn tới RCE (remote code execution) → (2) kẻ tấn công thực thi được lệnh shell bên trong container, với quyền của user mà process đang chạy — nếu đó là root, kẻ tấn công có toàn quyền trong container (đọc/ghi mọi file, cài package, tắt log) → (3) nếu container có lỗ hổng escape (kernel bug, Docker socket bị mount nhầm vào container, hoặc cấu hình privileged) thì quyền root *trong* container mở đường thành quyền root *trên host*, vì nhiều kỹ thuật escape đòi hỏi capability chỉ root mới có.
>
> Lệnh `USER appuser` cắt đứt chuỗi ngay ở bước (2): dù code bị khai thác, lệnh thực thi được cũng chỉ mang quyền của `appuser` — không ghi được vào thư mục hệ thống, không cài package, và hầu hết kỹ thuật escape container đòi hỏi root sẽ không thực hiện được.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Với đếm theo phút đồng hồ (reset lúc giây 00), hạn mức 10/phút: gửi 10 request lúc 10:00:59 (tính vào cửa sổ phút 10:00, chưa vượt) rồi gửi tiếp 10 request lúc 10:01:01 (cửa sổ phút 10:01 vừa reset về 0, cũng chưa vượt) → tổng cộng **20 request trong 2 giây**, gấp đôi hạn mức thật, mà hệ thống đếm-theo-phút vẫn coi là hợp lệ ở cả hai phía. Sliding window không có lỗ hổng này vì nó luôn nhìn lại đúng 60 giây gần nhất tính từ thời điểm hiện tại, không có ranh giới cố định để "né".

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Khác nhau: rate limit giới hạn *số lượng* request/phút bất kể mỗi request tốn bao nhiêu; cost guard giới hạn *tổng tiền* tiêu trong tháng bất kể tốc độ gửi.
>
> - *Rate limit cho qua, cost guard chặn:* user gửi đúng 3 request/phút (dưới hạn mức 10/phút) nhưng mỗi câu hỏi rất dài (gần 2000 ký tự, sát giới hạn `AskRequest`), tốn nhiều token mỗi lần → chưa chạm rate limit nhưng vài request là đủ vượt `monthly_budget_usd` → 402.
> - *Cost guard cho qua, rate limit chặn:* user gửi câu hỏi cực ngắn ("hi", "ok"...) liên tục 15 lần trong 1 phút, mỗi lần tốn gần như 0 đồng (ngân sách tháng còn dư rất nhiều) → cost guard không có lý do chặn, nhưng request thứ 11 trở đi đã vượt `rate_limit_per_minute=10` → 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Nếu gộp `/health` và `/ready` làm một, cùng kiểm tra Redis, với cụm 3 container: (1) Redis mất kết nối → cả 3 container đồng loạt fail check "Redis" trong endpoint gộp đó → (2) orchestrator hiểu nhầm là **process** của cả 3 container đều "không còn sống" (vì health check là liveness probe) chứ không phải chỉ "chưa sẵn sàng nhận traffic" → (3) orchestrator restart cả 3 container gần như cùng lúc để cố khắc phục → (4) trong lúc cả 3 đang restart, không còn container nào phục vụ được — toàn bộ service down, dù Redis chỉ mất kết nối tạm 30 giây và bản thân process Python hoàn toàn khỏe mạnh → (5) kể cả khi Redis hồi phục trong 30 giây, các container vẫn đang trong chu trình restart/khởi động lại nên downtime kéo dài hơn 30 giây ban đầu rất nhiều. Tách riêng `/health` (không đụng Redis) giữ cho orchestrator biết "process còn sống, đừng restart", còn `/ready` (có đụng Redis) chỉ khiến load balancer tạm ngừng đẩy traffic vào — nhẹ nhàng hơn nhiều so với restart cả cụm.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Khi chạy `docker compose up --scale agent=3` rồi gọi `/ask` liên tục với cùng `X-User-Id`, `history_length` trong response tăng đều đặn (0, 2, 4, 6...) bất kể request rơi vào container nào trong 3 container, vì lịch sử nằm trong Redis — nơi cả 3 container cùng đọc/ghi chung. Nếu lịch sử được lưu trong một `dict` Python (RAM của từng process) thay vì Redis, mỗi container sẽ có bộ nhớ lịch sử hoàn toàn riêng biệt: nginx round-robin request giữa 3 container, nên `history_length` sẽ nhảy lung tung không tăng đều (ví dụ 0, 0, 2, 0, 2, 4... tùy request rơi vào container nào) — vì mỗi container chỉ "nhớ" những request mà chính nó từng xử lý, chứ không thấy được request mà 2 container kia đã xử lý.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi gặp phải: sau khi Railway báo Build/Deploy thành công nhưng **Network → Healthcheck failed**. Xem Deploy Logs thấy:
> ```
> Error: Invalid value for '--port': '$PORT' is not a valid integer.
> ```
> Nguyên nhân: file `railway.toml` có `startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"`. Railway chạy `startCommand` **không thông qua shell**, nên biến `$PORT` không được shell mở rộng thành số cổng thật mà bị truyền nguyên văn dạng chuỗi `"$PORT"` vào uvicorn, khiến uvicorn không parse được thành số nguyên và crash ngay khi khởi động — healthcheck vì vậy luôn timeout vì server chưa từng thực sự chạy.
>
> Cách sửa: xóa dòng `startCommand` khỏi `railway.toml`, để Railway dùng thẳng `CMD` đã khai báo sẵn trong `Dockerfile` — vốn đã bọc trong `sh -c "... --port ${PORT:-8000}"`, nên `$PORT` được chính shell (chứ không phải Railway) mở rộng đúng giá trị trước khi truyền cho uvicorn.

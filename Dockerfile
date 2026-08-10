# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Multi-stage build: stage `builder` cài dependency, stage runtime chỉ
# copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ---- Stage 1: Builder ----
FROM python:3.11-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: Production ----
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/ app/
COPY utils/ utils/

# Chạy dưới quyền user thường
RUN adduser --disabled-login --no-create-home appuser
USER appuser

EXPOSE 8000

# Health check dùng Python (image slim không có curl, đọc PORT động)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import os, urllib.request; port = os.getenv('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=3)"

# Sử dụng shell form để expand biến $PORT khi chạy trên cloud
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]

# MyAIGateway

## Cài đặt và chạy LiteLLM

Hướng dẫn dành cho Windows PowerShell, chạy từ thư mục gốc repository. PostgreSQL
chạy trong Docker; LiteLLM chạy trực tiếp trên máy.

### Yêu cầu

- Docker Desktop đang chạy.
- Python và API keys cho các model (`OPENAI_API_KEY`, `GEMINI_API_KEY`).

### 1. Cài thư viện

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r setup.txt
```

### 2. Cấu hình môi trường

Chạy trong cùng cửa sổ PowerShell dùng để khởi động proxy:

```powershell
$env:DATABASE_URL = "postgresql://litellm:litellm@localhost:5432/litellm"
$env:LITELLM_MASTER_KEY = "sk-thay-bang-khoa-ngau-nhien-cua-ban"
$env:OPENAI_API_KEY = "thay-bang-openai-api-key"
$env:GEMINI_API_KEY = "thay-bang-gemini-api-key"
```

Các thông tin database phải khớp với `corp/docker-compose.yaml`. Thay các giá trị
ví dụ bằng khóa thật; không commit các khóa này lên Git.

### 3. Khởi động database và tạo Prisma Client

```powershell
docker compose -f corp\docker-compose.yaml up -d postgres
docker compose -f corp\docker-compose.yaml ps
$env:PATH = "$PWD\.venv\Scripts;$env:PATH"
python -m prisma generate --schema ".venv\Lib\site-packages\litellm\proxy\schema.prisma"
```

Chờ container `litellm_db` ở trạng thái `healthy` trước khi tiếp tục. Chỉ cần
tạo Prisma Client lại khi cài mới hoặc cập nhật dependencies.

### 4. Chạy và kiểm tra proxy

```powershell
.\.venv\Scripts\litellm.exe --config corp\config.yaml --port 4000
```

Mở `http://localhost:4000` để xem API docs. Kiểm tra database tại
`http://localhost:4000/health/readiness`; kết quả đúng có `"db":"connected"`.
Giữ cửa sổ PowerShell đang chạy proxy mở; nhấn `Ctrl+C` để dừng.

### Chạy lại lần sau

Mở Docker Desktop, đặt lại các biến môi trường ở bước 2 trong PowerShell, sau đó
chạy từ thư mục gốc:

```powershell
docker compose -f corp\docker-compose.yaml up -d postgres
.\.venv\Scripts\litellm.exe --config corp\config.yaml --port 4000
```

### Nếu gặp lỗi

- `Missing Environment Variables DATABASE_URL`: đặt biến `DATABASE_URL` trong
  đúng cửa sổ PowerShell trước khi chạy proxy.
- Database không kết nối được: kiểm tra container healthy và thông tin đăng nhập
  trong URL có khớp với `corp/docker-compose.yaml`.
- Gọi model bị lỗi xác thực: kiểm tra API key của nhà cung cấp trong môi trường.

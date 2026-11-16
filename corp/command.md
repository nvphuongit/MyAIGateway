Các bước : 

1. Khởi tạo database theo thiết lập trong docker-compose/yaml :

		docker compose up -d

2. Thiết lập đường dẫn DATABASE_ULL

Trên Linux/Mac OS
export DATABASE_URL="postgresql://litellm:pw@localhost:5432/litellm"

Trên window : 

set DATABASE_URL=postgresql://litellm:pw@localhost:5432/litellm

set DATABASE_URL=postgresql://litellm:pw@pm3a-173:5432/litellm

nếu ko kết nối dc thì vào system/enviria/variables


3. Cài LiteLLM :

pip install 'Litellm[extra_proxy]'


pip install websockets

(nếu thiếu)


$env:DATABASE_URL="postgresql://litellm:pw@localhost:5432/litellm"

pip install prisma

(neu chay lần đầu)

prisma generate --schema=C:\Users\Administrator\AppData\Local\Programs\Python\Python314\Lib\site-packages\litellm\proxy\schema.prisma

(neu chay lần đầu)

litellm --config config.yaml


4. 

prisma generate --schema="$(python -c "import litellm, os; print(os.path.join(os.path.dirname(litellm.__file__), 'proxy', 'schema.prisma'))")"

sk-pc0WLFep6d_uV3rsqX9krA

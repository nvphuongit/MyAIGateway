param()

$ErrorActionPreference = "Stop"
$repositoryRoot = $PSScriptRoot
$venvPath = Join-Path $repositoryRoot ".venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"
$litellm = Join-Path $venvPath "Scripts\litellm.exe"
$databaseUrl = "postgresql://litellm:litellm@localhost:5432/litellm"
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

function Get-EnvironmentSecret {
    param(
        [string]$Name,
        [string]$Prompt
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        $secureValue = Read-Host $Prompt -AsSecureString
        if ($secureValue.Length -eq 0) {
            throw "$Name cannot be empty."
        }

        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
        try {
            $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }

    return $value
}

function Invoke-CheckedCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($Arguments -join ' ')"
    }
}

Push-Location $repositoryRoot
try {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCommand) {
        throw "Python 3.9 or newer was not found on PATH."
    }

    if (-not (Test-Path $venvPython)) {
        Invoke-CheckedCommand -FilePath $pythonCommand.Source -Arguments @("-m", "venv", $venvPath)
    }

    $pythonVersion = & $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not determine the Python version in .venv."
    }
    $versionParts = $pythonVersion.Trim().Split(".")
    if ([int]$versionParts[0] -lt 3 -or ([int]$versionParts[0] -eq 3 -and [int]$versionParts[1] -lt 9)) {
        throw "Python 3.9 or newer is required; .venv uses Python $($pythonVersion.Trim()). Remove .venv and rerun with a supported Python on PATH."
    }

    Invoke-CheckedCommand -FilePath $venvPython -Arguments @("-m", "pip", "install", "--upgrade", "pip")
    Invoke-CheckedCommand -FilePath $venvPython -Arguments @("-m", "pip", "install", "-r", "setup.txt")

    $env:DATABASE_URL = $databaseUrl
    $env:LITELLM_MASTER_KEY = Get-EnvironmentSecret "LITELLM_MASTER_KEY" "Enter the LiteLLM master key"
    $env:OPENAI_API_KEY = Get-EnvironmentSecret "OPENAI_API_KEY" "Enter the OpenAI API key"
    $env:GEMINI_API_KEY = Get-EnvironmentSecret "GEMINI_API_KEY" "Enter the Gemini API key"

    Invoke-CheckedCommand -FilePath "docker" -Arguments @("compose", "-f", "corp\docker-compose.yaml", "up", "-d", "postgres")

    $healthStatus = ""
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $healthStatus = (& docker inspect --format "{{.State.Health.Status}}" litellm_db 2>$null)
        if ($LASTEXITCODE -eq 0 -and $healthStatus.Trim() -eq "healthy") {
            break
        }
        Start-Sleep -Seconds 2
    }
    if ($healthStatus.Trim() -ne "healthy") {
        throw "PostgreSQL container did not become healthy. Check Docker Desktop and run: docker compose -f corp\docker-compose.yaml logs postgres"
    }

    $env:PATH = "$(Join-Path $venvPath 'Scripts');$env:PATH"
    $prismaSchema = Join-Path $venvPath "Lib\site-packages\litellm\proxy\schema.prisma"
    if (-not (Test-Path $prismaSchema)) {
        throw "LiteLLM Prisma schema was not found at $prismaSchema."
    }
    Invoke-CheckedCommand -FilePath $venvPython -Arguments @("-m", "prisma", "generate", "--schema", $prismaSchema)

    Write-Host "`nStarting LiteLLM at http://localhost:4000"
    Write-Host "Press Ctrl+C to stop the proxy."
    & $litellm --host 127.0.0.1 --config corp\config.yaml --port 4000
    if ($LASTEXITCODE -ne 0) {
        throw "LiteLLM exited with code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

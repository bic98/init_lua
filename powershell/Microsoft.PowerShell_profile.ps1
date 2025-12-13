# Oh My Posh 설정
$env:Path += ";C:\Users\BaekInchan\AppData\Local\Programs\oh-my-posh\bin"
oh-my-posh init pwsh --config "C:\Users\BaekInchan\AppData\Local\Programs\oh-my-posh\themes\illusi0n.omp.json" | Invoke-Expression

function ppe {
    Set-Location "C:\Users\BaekInchan\AppData\Roaming\pyRevit\Extensions"
}

function root {
    Set-Location C:\
}

function e {
    Set-Location E:\
}

function rhino {
    Start-Process "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Rhino 8\Rhino 8.lnk"
}

function revit {
    Start-Process "C:\Program Files\Autodesk\Revit 2024\Revit.exe"
}

function acad {
    Start-Process "C:\Program Files\Autodesk\AutoCAD 2023\acad.exe"
}

function boj {
    Set-Location "C:\Users\BaekInchan\boj"
    nvim
}

function env_path {
    param(
        [string]$NewPath
    )

    if (-not (Test-Path $NewPath)) {
        Write-Host "경로가 존재하지 않습니다: $NewPath"
        return
    }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)

    if ($currentPath -like "*$NewPath*") {
        Write-Host "이미 시스템 PATH에 존재합니다: $NewPath"
    }
    else {
        [Environment]::SetEnvironmentVariable(
            "Path",
            $currentPath + ";$NewPath",
            [EnvironmentVariableTarget]::Machine
        )
        Write-Host "시스템 PATH에 추가 완료: $NewPath"
    }
}

function gh_venv {
    if ($env:VIRTUAL_ENV) {
        deactivate
    }
    else {
        & "C:\Users\BaekInchan\grasshopper\Scripts\Activate.ps1"
    }
}

$env:Path += ';C:\Users\BaekInchan\AppData\Roaming\npm'

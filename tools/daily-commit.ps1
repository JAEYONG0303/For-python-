<#
    daily-commit.ps1
    ---------------------------------------------------------
    학원수업 저장소를 하루에 한 번 자동으로 commit / push 한다.
    Windows 작업 스케줄러가 매일 정해진 시각에 이 파일을 실행한다.

    - 변경된 파일이 없으면 아무것도 하지 않는다 (빈 커밋을 만들지 않음)
    - 커밋 메시지는 그날 바뀐 파일에서 자동으로 만든다
    - 실행 결과는 tools/daily-commit.log 에 남는다

    직접 실행해 볼 때:
        pwsh -File "tools\daily-commit.ps1"           # 커밋 + push
        pwsh -File "tools\daily-commit.ps1" -DryRun   # 무엇을 할지 보기만
        pwsh -File "tools\daily-commit.ps1" -NoPush   # 커밋만 하고 push 안 함
#>

param(
    [string]$RepoPath = "C:\Users\wodyd\Desktop\학원수업",
    [switch]$NoPush,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- git 실행 파일 찾기 ---------------------------------------------------
# 작업 스케줄러는 PATH 가 평소와 다를 수 있어서, 없으면 기본 설치 경로를 쓴다.
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = "C:\Program Files\Git\cmd\git.exe" }
if (-not (Test-Path $git)) { throw "git 을 찾을 수 없습니다: $git" }

$logFile = Join-Path $RepoPath "tools\daily-commit.log"


function Write-Log {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}


# git 을 저장소 안에서 실행한다.
#   -C          : 어느 폴더에서 실행하든 저장소를 정확히 가리키게 한다
#   quotepath   : 한글 파일명이 \355\225\234 처럼 깨져 나오는 것을 막는다
# stderr(줄바꿈 경고 등)는 표준 출력과 섞이지 않도록 따로 버린다.
# param 블록을 두지 않아야 -A, -m 같은 git 옵션을 PowerShell 이 가로채지 않는다.
function Invoke-Git {
    & $git -C $RepoPath -c core.quotepath=false @args 2>$null
}


try {
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "git 저장소가 아닙니다: $RepoPath"
    }

    # 1) 변경분을 모두 스테이징한다 (.gitignore 에 걸린 파일은 자동 제외)
    Invoke-Git add -A | Out-Null

    # 2) 스테이징된 것이 없으면 오늘은 할 일이 없다
    #    출력 형식은 "M<탭>파일경로" 이므로 그 형태인 줄만 골라 쓴다.
    $status = @(Invoke-Git diff --cached --name-status | Where-Object { $_ -match "^[A-Z]\d*\t" })

    if ($status.Count -eq 0) {
        Write-Log "변경 없음 - 커밋하지 않았습니다."
        return
    }

    # 3) 변경 목록을 사람이 읽을 수 있는 형태로 정리한다
    $label = @{ "A" = "추가"; "M" = "수정"; "D" = "삭제"; "R" = "이름변경"; "C" = "복사" }
    $files = @()

    foreach ($line in $status) {
        $code, $path = $line -split "`t", 2

        $kind = $label[$code.Substring(0, 1)]
        if (-not $kind) { $kind = $code }

        $files += [pscustomobject]@{ Kind = $kind; Path = $path }
    }

    # 4) 커밋 메시지를 만든다
    #    제목 : 2026-08-18 수업 정리: LAB 3. 파이썬 외 2건
    #    본문 : 바뀐 파일 목록
    $today = Get-Date -Format "yyyy-MM-dd"

    # 제목에는 그날의 대표 파일을 쓴다. 노트북이 있으면 노트북을 우선한다.
    $main = $files | Where-Object { $_.Path -like "*.ipynb" } | Select-Object -First 1
    if (-not $main) { $main = $files[0] }

    $head = [System.IO.Path]::GetFileNameWithoutExtension($main.Path)
    if (-not $head) { $head = Split-Path $main.Path -Leaf }   # .gitignore 처럼 이름이 없는 파일

    $rest = $files.Count - 1

    if ($rest -gt 0) {
        $subject = "$today 수업 정리: $head 외 ${rest}건"
    } else {
        $subject = "$today 수업 정리: $head"
    }

    $list = ($files | ForEach-Object { "- [$($_.Kind)] $($_.Path)" }) -join "`n"
    $body = "변경 파일 $($files.Count)개`n`n$list"

    # 5) -DryRun 이면 스테이징을 되돌리고 내용만 보여준다
    if ($DryRun) {
        Write-Log "[DryRun] 아래 내용으로 커밋할 예정입니다."
        Write-Host ""
        Write-Host $subject
        Write-Host ""
        Write-Host $body
        Write-Host ""

        Invoke-Git reset | Out-Null
        return
    }

    # 6) 커밋
    Invoke-Git commit -m $subject -m $body | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "커밋 실패 (exit $LASTEXITCODE)"
        exit 1
    }
    Write-Log "커밋 완료 - $subject"

    # 7) push
    if ($NoPush) {
        Write-Log "push 생략 (-NoPush)"
        return
    }

    Invoke-Git push origin HEAD | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "push 실패 (exit $LASTEXITCODE) - 인터넷 연결이나 SSH 키를 확인하세요."
        exit 1
    }
    Write-Log "push 완료 - origin/main"
}
catch {
    Write-Log "오류 - $($_.Exception.Message)"
    exit 1
}

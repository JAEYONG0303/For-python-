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

    ※ 한글 처리 주의
      Windows PowerShell 5.1 은 외부 프로그램에 넘기는 인자를 UTF-8 이 아닌
      시스템 코드페이지(cp949)로 바꾼다. 그래서 이 스크립트는
        - git 에 한글 경로를 인자로 넘기지 않고  (-C 대신 Push-Location)
        - 한글 커밋 메시지도 인자가 아니라 파일로 넘긴다  (-m 대신 -F)
      두 가지를 지킨다. 이걸 바꾸면 한글이 깨진다.
#>

param(
    [string]$RepoPath = "C:\Users\wodyd\Desktop\학원수업",
    [switch]$NoPush,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# git 이 UTF-8 로 내보내는 파일 이름을 그대로 읽기 위해 콘솔 입출력을 UTF-8 로 맞춘다.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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


# git 을 현재 위치(= 저장소 안)에서 실행한다.
# param 블록을 두지 않아야 -A, -m 같은 git 옵션을 PowerShell 이 가로채지 않는다.
function Invoke-Git {
    # git 은 "LF will be replaced by CRLF" 같은 안내도 stderr 로 보낸다.
    # 이걸 오류로 취급하면 스크립트가 멈추므로 이 함수 안에서만 Stop 을 푼다.
    $ErrorActionPreference = "Continue"

    & $git -c core.quotepath=false @args 2>$null
}


try {
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "git 저장소가 아닙니다: $RepoPath"
    }

    Push-Location $RepoPath

    # 1) 변경분을 모두 스테이징한다 (.gitignore 에 걸린 파일은 자동 제외)
    Invoke-Git add -A | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git add 실패 (exit $LASTEXITCODE)" }

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

        # 공백이 든 파일 이름은 git 이 따옴표로 감싸 주므로 벗겨낸다
        $files += [pscustomobject]@{ Kind = $kind; Path = $path.Trim('"') }
    }

    # 4) 커밋 메시지를 만든다
    #    제목 : 2026-08-18 수업 정리: LAB 3. 파이썬 외 2건
    #    본문 : 바뀐 파일 목록
    $today = Get-Date -Format "yyyy-MM-dd"

    # 제목에는 그날의 대표 파일을 쓴다. 노트북이 있으면 노트북을 우선한다.
    $notebook = $files | Where-Object { $_.Path -like "*.ipynb" } | Select-Object -First 1

    if ($notebook) {
        $main  = $notebook
        $topic = "수업 정리"
    } else {
        $main  = $files[0]
        $topic = "저장소 정리"      # 노트북이 아니라 설정, 문서 등만 바뀐 날
    }

    $head = [System.IO.Path]::GetFileNameWithoutExtension($main.Path)
    if (-not $head) { $head = Split-Path $main.Path -Leaf }   # .gitignore 처럼 이름이 없는 파일

    $rest = $files.Count - 1

    if ($rest -gt 0) {
        $subject = "$today ${topic}: $head 외 ${rest}건"
    } else {
        $subject = "$today ${topic}: $head"
    }

    $list    = ($files | ForEach-Object { "- [$($_.Kind)] $($_.Path)" }) -join "`n"
    $message = "$subject`n`n변경 파일 $($files.Count)개`n`n$list`n"

    # 5) -DryRun 이면 스테이징을 되돌리고 내용만 보여준다
    if ($DryRun) {
        Write-Log "[DryRun] 아래 내용으로 커밋할 예정입니다."
        Write-Host ""
        Write-Host $message

        Invoke-Git reset | Out-Null
        return
    }

    # 6) 커밋
    #    한글이 깨지지 않도록 메시지를 UTF-8 파일(BOM 없음)로 써서 -F 로 넘긴다.
    $msgFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($msgFile, $message, (New-Object System.Text.UTF8Encoding $false))

    try {
        Invoke-Git commit -F $msgFile | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git commit 실패 (exit $LASTEXITCODE)" }
    }
    finally {
        Remove-Item $msgFile -Force -ErrorAction SilentlyContinue
    }

    Write-Log "커밋 완료 - $subject"

    # 7) push
    if ($NoPush) {
        Write-Log "push 생략 (-NoPush)"
        return
    }

    Invoke-Git push origin HEAD | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git push 실패 (exit $LASTEXITCODE) - 인터넷 연결이나 SSH 키를 확인하세요."
    }

    Write-Log "push 완료 - origin/main"
}
catch {
    Write-Log "오류 - $($_.Exception.Message)"
    exit 1
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
}

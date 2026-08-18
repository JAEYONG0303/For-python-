<#
    register-task.ps1
    ---------------------------------------------------------
    daily-commit.ps1 을 매일 정해진 시각에 실행하도록
    Windows 작업 스케줄러에 등록한다.

        pwsh -File "tools\register-task.ps1"              # 매일 22:00 에 실행
        pwsh -File "tools\register-task.ps1" -At "07:30"  # 시각 변경 (다시 실행하면 덮어씀)
        pwsh -File "tools\register-task.ps1" -Remove      # 등록 해제

    관리자 권한은 필요 없다. 내 계정에 로그인해 있을 때만 실행된다
    (SSH 키와 인터넷 연결이 있어야 push 가 되기 때문).
#>

param(
    [string]$RepoPath = "C:\Users\wodyd\Desktop\학원수업",
    [string]$At       = "22:00",
    [string]$TaskName = "학원수업 매일 자동 커밋",
    [switch]$Remove
)

$ErrorActionPreference = "Stop"

# 작업 스케줄러에서는 경로가 바뀌지 않는 Windows PowerShell 을 쓴다.
# (pwsh 는 스토어 설치라 버전이 오르면 경로가 바뀐다)
$shell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "등록 해제 완료: $TaskName"
    return
}

$script = Join-Path $RepoPath "tools\daily-commit.ps1"
if (-not (Test-Path $script)) { throw "실행할 스크립트가 없습니다: $script" }

$action = New-ScheduledTaskAction -Execute $shell -WorkingDirectory $RepoPath -Argument (
    '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "tools\daily-commit.ps1"'
)

$trigger = New-ScheduledTaskTrigger -Daily -At $At

# StartWhenAvailable : 그 시각에 PC 가 꺼져 있었으면 켜진 뒤에 이어서 실행한다
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 15)

$register = @{
    TaskName    = $TaskName
    Action      = $action
    Trigger     = $trigger
    Settings    = $settings
    Description = "학원수업 폴더의 변경분을 매일 $At 에 GitHub(For-python-) 로 커밋/푸시한다. 변경이 없으면 아무것도 하지 않는다."
    Force       = $true
}

Register-ScheduledTask @register | Out-Null

$info = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "등록 완료: $TaskName"
Write-Host "  실행 시각   : 매일 $At"
Write-Host "  다음 실행   : $($info.NextRunTime)"
Write-Host "  실행 스크립트: $script"

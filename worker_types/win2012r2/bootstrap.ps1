# use TLS 1.2 (see bug 1443595)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# capture env
Get-ChildItem Env: | Out-File "C:\install_env.txt"

# needed for making http requests
$client = New-Object system.net.WebClient
$shell = new-object -com shell.application

# utility function to download a zip file and extract it
function Expand-ZIPFile($file, $destination, $url)
{
    $client.DownloadFile($url, $file)
    $zip = $shell.NameSpace($file)
    foreach($item in $zip.items())
    {
        $shell.Namespace($destination).copyhere($item)
    }
}

# allow powershell scripts to run
Set-ExecutionPolicy Unrestricted -Force -Scope Process

# install chocolatey package manager
Invoke-Expression ($client.DownloadString('https://chocolatey.org/install.ps1'))

# install Windows SDK 8.1
choco install -y windows-sdk-8.1

# install June 2010 DirectX SDK for compatibility with Win XP
$client.DownloadFile("http://download.microsoft.com/download/A/E/7/AE743F1F-632B-4809-87A9-AA1BB3458E31/DXSDK_Jun10.exe", "C:\DXSDK_Jun10.exe")

# prerequisite for June 2010 DirectX SDK is to install ".NET Framework 3.5 (includes .NET 2.0 and 3.0)"
Install-WindowsFeature NET-Framework-Core

# now run DirectX SDK installer
Start-Process C:\DXSDK_Jun10.exe -ArgumentList "/U" -Wait -NoNewWindow -PassThru -RedirectStandardOutput C:\directx_sdk_install.log -RedirectStandardError C:\directx_sdk_install.err

# install rustc dependencies (32 bit)
$client.DownloadFile("http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe", "C:\vcredist_x86-vs2013.exe")
Start-Process "C:\vcredist_x86-vs2013.exe" -ArgumentList "/install /passive /norestart /log C:\vcredist_x86-vs2013-install.log" -Wait -PassThru

# install rustc dependencies (64 bit)
$client.DownloadFile("http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe", "C:\vcredist_x64-vs2013.exe")
Start-Process "C:\vcredist_x64-vs2013.exe" -ArgumentList "/install /passive /norestart /log C:\vcredist_x64-vs2013-install.log" -Wait -PassThru

# install more rustc dependencies (32 bit)
$client.DownloadFile("http://download.microsoft.com/download/f/3/9/f39b30ec-f8ef-4ba3-8cb4-e301fcf0e0aa/vc_redist.x86.exe", "C:\vcredist_x86-vs2015.exe")
Start-Process "C:\vcredist_x86-vs2015.exe" -ArgumentList "/install /passive /norestart /log C:\vcredist_x86-vs2015-install.log" -Wait -PassThru

# install more rustc dependencies (64 bit)
$client.DownloadFile("http://download.microsoft.com/download/4/c/b/4cbd5757-0dd4-43a7-bac0-2a492cedbacb/vc_redist.x64.exe", "C:\vcredist_x64-vs2015.exe")
Start-Process "C:\vcredist_x64-vs2015.exe" -ArgumentList "/install /passive /norestart /log C:\vcredist_x64-vs2015-install.log" -Wait -PassThru

# install mozilla-build yasm dependencies (32 bit)
$client.DownloadFile("http://download.microsoft.com/download/C/6/D/C6D0FD4E-9E53-4897-9B91-836EBA2AACD3/vcredist_x86.exe", "C:\vcredist_x86-vs2010.exe")
Start-Process "C:\vcredist_x86-vs2010.exe" -ArgumentList "/install /passive /norestart /log C:\vcredist_x86-vs2010-install.log" -Wait -PassThru

# install mozilla-build yasm dependencies (64 bit)
$client.DownloadFile("http://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe", "C:\vcredist_x64-vs2010.exe")
Start-Process "C:\vcredist_x64-vs2010.exe" -ArgumentList "/install /passive /norestart /log C:\vcredist_x64-vs2010-install.log" -Wait -PassThru

# download mozilla-build installer
$client.DownloadFile("https://ftp.mozilla.org/pub/mozilla.org/mozilla/libraries/win32/MozillaBuildSetup-Latest.exe", "C:\MozillaBuildSetup.exe")

# run mozilla-build installer in silent (/S) mode
Start-Process "C:\MozillaBuildSetup.exe" -ArgumentList "/S" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\MozillaBuild_install.log" -RedirectStandardError "C:\MozillaBuild_install.err"

# Create C:\builds and give full access to all users (for hg-shared, tooltool_cache, etc)
md "C:\builds"
$acl = Get-Acl -Path "C:\builds"
$ace = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone","Full","ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($ace)
Set-Acl "C:\builds" $acl

# download tooltool
$client.DownloadFile("https://raw.githubusercontent.com/mozilla/release-services/master/src/tooltool/client/tooltool.py", "C:\builds\tooltool.py")

# install nssm
Expand-ZIPFile -File "C:\nssm-2.24.zip" -Destination "C:\" -Url "http://www.nssm.cc/release/nssm-2.24.zip"

# download generic-worker
md C:\generic-worker
$client.DownloadFile("https://github.com/taskcluster/generic-worker/releases/download/v16.2.0/generic-worker-multiuser-windows-amd64.exe", "C:\generic-worker\generic-worker.exe")

# download livelog
$client.DownloadFile("https://github.com/taskcluster/livelog/releases/download/v1.1.0/livelog-windows-amd64.exe", "C:\generic-worker\livelog.exe")

# download taskcluster-proxy
$client.DownloadFile("https://github.com/taskcluster/taskcluster-proxy/releases/download/v5.1.0/taskcluster-proxy-windows-amd64.exe", "C:\generic-worker\taskcluster-proxy.exe")

# configure hosts file for taskcluster-proxy access via http://taskcluster
$HostsFile_Base64 = "IyBDb3B5cmlnaHQgKGMpIDE5OTMtMjAwOSBNaWNyb3NvZnQgQ29ycC4NCiMNCiMgVGhpcyBpcyBhIHNhbXBsZSBIT1NUUyBmaWxlIHVzZWQgYnkgTWljcm9zb2Z0IFRDUC9JUCBmb3IgV2luZG93cy4NCiMNCiMgVGhpcyBmaWxlIGNvbnRhaW5zIHRoZSBtYXBwaW5ncyBvZiBJUCBhZGRyZXNzZXMgdG8gaG9zdCBuYW1lcy4gRWFjaA0KIyBlbnRyeSBzaG91bGQgYmUga2VwdCBvbiBhbiBpbmRpdmlkdWFsIGxpbmUuIFRoZSBJUCBhZGRyZXNzIHNob3VsZA0KIyBiZSBwbGFjZWQgaW4gdGhlIGZpcnN0IGNvbHVtbiBmb2xsb3dlZCBieSB0aGUgY29ycmVzcG9uZGluZyBob3N0IG5hbWUuDQojIFRoZSBJUCBhZGRyZXNzIGFuZCB0aGUgaG9zdCBuYW1lIHNob3VsZCBiZSBzZXBhcmF0ZWQgYnkgYXQgbGVhc3Qgb25lDQojIHNwYWNlLg0KIw0KIyBBZGRpdGlvbmFsbHksIGNvbW1lbnRzIChzdWNoIGFzIHRoZXNlKSBtYXkgYmUgaW5zZXJ0ZWQgb24gaW5kaXZpZHVhbA0KIyBsaW5lcyBvciBmb2xsb3dpbmcgdGhlIG1hY2hpbmUgbmFtZSBkZW5vdGVkIGJ5IGEgJyMnIHN5bWJvbC4NCiMNCiMgRm9yIGV4YW1wbGU6DQojDQojICAgICAgMTAyLjU0Ljk0Ljk3ICAgICByaGluby5hY21lLmNvbSAgICAgICAgICAjIHNvdXJjZSBzZXJ2ZXINCiMgICAgICAgMzguMjUuNjMuMTAgICAgIHguYWNtZS5jb20gICAgICAgICAgICAgICMgeCBjbGllbnQgaG9zdA0KDQojIGxvY2FsaG9zdCBuYW1lIHJlc29sdXRpb24gaXMgaGFuZGxlZCB3aXRoaW4gRE5TIGl0c2VsZi4NCiMJMTI3LjAuMC4xICAgICAgIGxvY2FsaG9zdA0KIwk6OjEgICAgICAgICAgICAgbG9jYWxob3N0DQoNCiMgVXNlZnVsIGZvciBnZW5lcmljLXdvcmtlciB0YXNrY2x1c3Rlci1wcm94eSBpbnRlZ3JhdGlvbg0KIyBTZWUgaHR0cHM6Ly9idWd6aWxsYS5tb3ppbGxhLm9yZy9zaG93X2J1Zy5jZ2k/aWQ9MTQ0OTk4MSNjNg0KMTI3LjAuMC4xICAgICAgICB0YXNrY2x1c3RlciAgICANCg=="
$HostsFile_Content = [System.Convert]::FromBase64String($HostsFile_Base64)
Set-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $HostsFile_Content -Encoding Byte

# install generic-worker
Start-Process C:\generic-worker\generic-worker.exe -ArgumentList "install service --configure-for-%MY_CLOUD% --nssm C:\nssm-2.24\win64\nssm.exe --config C:\generic-worker\generic-worker.config" -Wait -NoNewWindow -PassThru -RedirectStandardOutput C:\generic-worker\install.log -RedirectStandardError C:\generic-worker\install.err

# initial clone of mozilla-central
# Start-Process "C:\mozilla-build\python\python.exe" -ArgumentList "C:\mozilla-build\python\Scripts\hg clone -u null https://hg.mozilla.org/mozilla-central C:\gecko" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\hg_initial_clone.log" -RedirectStandardError "C:\hg_initial_clone.err"

# download Windows Server 2003 Resource Kit Tools
$client.DownloadFile("https://download.microsoft.com/download/8/e/c/8ec3a7d8-05b4-440a-a71e-ca3ee25fe057/rktools.exe", "C:\rktools.exe")

# download gvim
$client.DownloadFile("http://artfiles.org/vim.org/pc/gvim80-069.exe", "C:\gvim80-069.exe")

# https://bugzil.la/1274844 download BinScope
$client.DownloadFile("https://download.microsoft.com/download/2/6/A/26AAA1DE-D060-4246-93B5-7D7C877E4F8F/BinScopeSetup.msi", "C:\BinScopeSetup.msi")

# install BinScope
Start-Process "msiexec" -ArgumentList "/i C:\BinScopeSetup.msi /quiet" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\binscope-install.log" -RedirectStandardError "C:\binscope-install.err"

# open up firewall for livelog (both PUT and GET interfaces)
New-NetFirewallRule -DisplayName "Allow livelog PUT requests" -Direction Inbound -LocalPort 60022 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Allow livelog GET requests" -Direction Inbound -LocalPort 60023 -Protocol TCP -Action Allow

# install go (not required, but useful)
md "C:\gopath"
Expand-ZIPFile -File "C:\go1.11.5.windows-amd64.zip" -Destination "C:\" -Url "https://storage.googleapis.com/golang/go1.11.5.windows-amd64.zip"

# install PSTools
# md "C:\PSTools"
# Expand-ZIPFile -File "C:\PSTools\PSTools.zip" -Destination "C:\PSTools" -Url "https://download.sysinternals.com/files/PSTools.zip"

# install git
$client.DownloadFile("https://github.com/git-for-windows/git/releases/download/v2.16.2.windows.1/Git-2.16.2-64-bit.exe", "C:\Git-2.16.2-64-bit.exe")
Start-Process "C:\Git-2.16.2-64-bit.exe" -ArgumentList "/VERYSILENT /LOG=C:\git_install.log /NORESTART /SUPPRESSMSGBOXES" -Wait -NoNewWindow

# install AZCopy (azure table storage backup utility - for bstack)
$client.DownloadFile("http://aka.ms/downloadazcopy", "C:\AZCopy.msi")
Start-Process "msiexec" -ArgumentList "/i C:\AZCopy.msi /quiet" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\AZCopy-install.log" -RedirectStandardError "C:\AZCopy-install.err"

# install node
$client.DownloadFile("https://nodejs.org/dist/v6.6.0/node-v6.6.0-x64.msi", "C:\NodeSetup.msi")
Start-Process "msiexec" -ArgumentList "/i C:\NodeSetup.msi /quiet" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\node-install.log" -RedirectStandardError "C:\node-install.err"

# set permanent env vars
[Environment]::SetEnvironmentVariable("GOROOT", "C:\go", "Machine")
[Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";C:\Program Files\Vim\vim80;C:\go\bin;C:\gopath\bin;C:\mozilla-build\python;C:\mozilla-build\python\Scripts;C:\Program Files\Git\cmd;C:\Program Files\nodejs", "Machine")
[Environment]::SetEnvironmentVariable("GOPATH", "C:\gopath", "Machine")

# upgrade python libraries
Start-Process "C:\mozilla-build\python\python.exe" -ArgumentList "-m pip install --upgrade pip==8.1.1 setuptools==20.7.0 virtualenv==15.0.3 wheel==0.29.0 pypiwin32==219 requests==2.9.1 psutil==4.1.0" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\python_package_upgrades.log" -RedirectStandardError "C:\python_package_upgrades.err"

# set env vars for the currently running process
$env:GOROOT = "C:\go"
$env:GOPATH = "C:\gopath"
$env:PATH   = $env:PATH + ";C:\go\bin;C:\gopath\bin;C:\mozilla-build\python;C:\mozilla-build\python\Scripts;C:\Program Files\Git\cmd"

# get generic-worker and livelog source code (note required, but useful)
Start-Process "go" -ArgumentList "get -t github.com/taskcluster/generic-worker github.com/taskcluster/livelog" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\generic-worker\go-get_install.log" -RedirectStandardError "C:\generic-worker\go-get_install.err"

# generate ed25519 key
Start-Process C:\generic-worker\generic-worker.exe -ArgumentList "new-ed25519-keypair --file C:\generic-worker\generic-worker-ed25519-signing-key.key" -Wait -NoNewWindow -PassThru -RedirectStandardOutput C:\generic-worker\generate-signing-key.log -RedirectStandardError C:\generic-worker\generate-signing-key.err

# download cygwin (not required, but useful)
$client.DownloadFile("https://www.cygwin.com/setup-x86_64.exe", "C:\cygwin-setup-x86_64.exe")

# install cygwin
# complete package list: https://cygwin.com/packages/package_list.html
Start-Process "C:\cygwin-setup-x86_64.exe" -ArgumentList "--quiet-mode --wait --root C:\cygwin --site http://cygwin.mirror.constant.com --packages openssh,vim,curl,tar,wget,zip,unzip,diffutils,bzr" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\cygwin_install.log" -RedirectStandardError "C:\cygwin_install.err"

# open up firewall for ssh daemon
New-NetFirewallRule -DisplayName "Allow SSH inbound" -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow

# workaround for https://www.cygwin.com/ml/cygwin/2015-10/msg00036.html
# see:
#   1) https://www.cygwin.com/ml/cygwin/2015-10/msg00038.html
#   2) https://cygwin.com/git/gitweb.cgi?p=cygwin-csih.git;a=blob;f=cygwin-service-installation-helper.sh;h=10ab4fb6d47803c9ffabdde51923fc2c3f0496bb;hb=7ca191bebb52ae414bb2a2e37ef22d94f2658dc7#l2884
$env:LOGONSERVER = "\\" + $env:COMPUTERNAME

# configure sshd (not required, but useful)
Start-Process "C:\cygwin\bin\bash.exe" -ArgumentList "--login -c `"ssh-host-config -y -c 'ntsec mintty' -u 'cygwinsshd' -w 'qwe123QWE!@#'`"" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\cygrunsrv.log" -RedirectStandardError "C:\cygrunsrv.err"

# start sshd
Start-Process "net" -ArgumentList "start sshd" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\net_start_sshd.log" -RedirectStandardError "C:\net_start_sshd.err"

# download bash setup script
$client.DownloadFile("https://raw.githubusercontent.com/petemoore/myscrapbook/master/setup.sh", "C:\cygwin\home\Administrator\setup.sh")

# run bash setup script
Start-Process "C:\cygwin\bin\bash.exe" -ArgumentList "--login -c 'chmod a+x setup.sh; ./setup.sh'" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "C:\Administrator_cygwin_setup.log" -RedirectStandardError "C:\Administrator_cygwin_setup.err"

# install dependencywalker (useful utility for troubleshooting, not required)
md "C:\DependencyWalker"
Expand-ZIPFile -File "C:\depends22_x64.zip" -Destination "C:\DependencyWalker" -Url "http://dependencywalker.com/depends22_x64.zip"

# install ProcessExplorer (useful utility for troubleshooting, not required)
md "C:\ProcessExplorer"
Expand-ZIPFile -File "C:\ProcessExplorer.zip" -Destination "C:\ProcessExplorer" -Url "https://download.sysinternals.com/files/ProcessExplorer.zip"

# install ProcessMonitor (useful utility for troubleshooting, not required)
md "C:\ProcessMonitor"
Expand-ZIPFile -File "C:\ProcessMonitor.zip" -Destination "C:\ProcessMonitor" -Url "https://download.sysinternals.com/files/ProcessMonitor.zip"

# now shutdown, in preparation for creating an image
# Stop-Computer isn't working, also not when specifying -AsJob, so reverting to using `shutdown` command instead
#   * https://www.reddit.com/r/PowerShell/comments/65250s/windows_10_creators_update_stopcomputer_not/dgfofug/?st=j1o3oa29&sh=e0c29c6d
#   * https://support.microsoft.com/en-in/help/4014551/description-of-the-security-and-quality-rollup-for-the-net-framework-4
#   * https://support.microsoft.com/en-us/help/4020459
shutdown -s

<!-- : 批处理脚本开始 
@chcp 65001 >nul
@setlocal DisableDelayedExpansion
@set uivr=v125
@echo off
:: ### 创建方法 ### 
::
:: 0 - 注册表操作            / 黑客方式，使用 install.wim 或 install.esd，支持任何主机操作系统 
:: 1 - Dism.exe 工具         / 官方方式，使用 install.wim，需要 NT 10.0 主机操作系统或已安装 Windows ADK 的 Windows 8.1 
:: 2 - 强制 Dism.exe 工具    / 与 1 相同，但在已安装 Windows ADK 的 Windows 7/8 上工作 
set UseDism=1

:: 更改为 1 以直接启动此过程，将创建在参数 AutoEditions 中指定的发行版本 
set AutoStart=0

:: 指定要用空格或逗号（,）分隔的目标发行版本 
:: 将其留空以创建 *所有* 可能的发行版本 
:: 请查看自述文件（ReadMe）了解详细信息 
set "AutoEditions="

:: 指定要按顺序排序的所有或任何发行版本，用空格或逗号（,）分隔。 
:: 请查看自述文件（ReadMe）了解详细信息 
set "SortEditions="

:: 更改为 1 删除源版本索引（例如：创建企业版并删除专业版） 
set DeleteSource=0

:: 0 - 源分发文件夹将被直接修改 
:: 1 - 源分发文件夹将会被复制，然后修改 
:: 如果源分发文件是 .ISO 文件，此选项将不工作 
set Preserve=0

:: 若将 install.wim 转换为 install.esd，请将此参数更改为 1 
set wim2esd=0

:: 若将 install.wim 拆分为多个 install.swm，请将此参数更改为 1 
:: 注：如果两个选项均为 1，install.esd 将优先执行 
set wim2swm=0

:: 若不创建 ISO 文件，请将值更改为 1，将保留安装媒介文件夹 
set SkipISO=0

:: 脚本编写：        abbodi1406 
:: 新方法：          whatever127 
:: wimlib：          synchronicity 
:: 脱机注册表：      erwan.l 

:: ###################################################################

set "_Null=1>nul 2>nul"
set DisableWimRebuilds=0
set "_wrb="
if %DisableWimRebuilds% equ 1 set "_wrb=rem."

set _uupc=0
set _Debug=0
set _type=
set qerel=
set _elev=
set _args=
set _args=%*
if not defined _args goto :NoProgArgs
if "%~1"=="" set "_args="&goto :NoProgArgs
for %%# in (%*) do call :parseArgs "%%#"
if defined _exTP1 if defined _exTP2 set "_exTime=%_exTP1%,%_exTP2%"
goto :NoProgArgs

:parseArgs
if "%~1"=="-elevated" (set _elev=1&exit /b)
if "%~1"=="-qedit" (set qerel=1&exit /b)
echo %~1|findstr /i "autoswm autowim autoesd manuswm manuwim manuesd extdism" >nul && (set "_type=%~1"&exit /b)
echo %~1|findstr \/ >nul && (set "_exTP1=%~1"&exit /b)
echo %~1|findstr :  >nul && (set "_exTP2=%~1"&exit /b)
echo %~1|findstr _  >nul && (set "_exLabel=%~1"&exit /b)
exit /b

:NoProgArgs
:: @color 07
set "xOS=amd64"
if /i "%PROCESSOR_ARCHITECTURE%"=="arm64" set "xOS=arm64"
if /i "%PROCESSOR_ARCHITECTURE%"=="x86" if "%PROCESSOR_ARCHITEW6432%"=="" set "xOS=x86"
if /i "%PROCESSOR_ARCHITEW6432%"=="amd64" set "xOS=amd64"
if /i "%PROCESSOR_ARCHITEW6432%"=="arm64" set "xOS=arm64"
set "xDS=bin\bin64;bin"
if /i not %xOS%==amd64 set "xDS=bin"
set "SysPath=%SystemRoot%\System32"
set "Path=%xDS%;%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\"
if exist "%SystemRoot%\Sysnative\reg.exe" (
set "SysPath=%SystemRoot%\Sysnative"
set "Path=%xDS%;%SystemRoot%\Sysnative;%SystemRoot%;%SystemRoot%\Sysnative\Wbem;%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\;%Path%"
)
set "_err=echo: &echo ==== 出错 ====" 
set "_psc=powershell -nop -c"
set winbuild=1
for /f "tokens=6 delims=[]. " %%# in ('ver') do set winbuild=%%#
set _cwmi=0
for %%# in (wmic.exe) do @if not "%%~$PATH:#"=="" (
cmd /c "wmic path Win32_ComputerSystem get CreationClassName /value" 2>nul | find /i "ComputerSystem" 1>nul && set _cwmi=1
)
set _pwsh=1
for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" set _pwsh=0
cmd /c "%_psc% "$ExecutionContext.SessionState.LanguageMode"" | find /i "FullLanguage" 1>nul || (set _pwsh=0)
call :pr_color
if %_cwmi% equ 0 if %_pwsh% equ 0 goto :E_PWS

set _uac=-elevated
%_Null% reg.exe query HKU\S-1-5-19 && (
  goto :Passed
  ) || (
  if defined _elev goto :E_Admin
)

set _PSarg="""%~f0""" %_uac%
if defined _args set _PSarg="""%~f0""" %_args:"="""% %_uac%
set _PSarg=%_PSarg:'=''%

(%_Null% cscript //NoLogo "%~f0?.wsf" //job:ELAV /File:"%~f0" %* %_uac%) && (
  exit /b
  ) || (
  call setlocal EnableDelayedExpansion
  %_Null% %_psc% "start cmd.exe -Arg '/c \"!_PSarg!\"' -verb runas" && (
    exit /b
    ) || (
    goto :E_Admin
  )
)

:Passed
if defined _type goto :skipQE
if %winbuild% LSS 10586 (
reg.exe query HKCU\Console /v QuickEdit 2>nul | find /i "0x0" >nul && set qerel=1
)
if defined qerel goto :skipQE
if %_pwsh% EQU 0 goto :skipQE
set _PSarg="""%~f0""" -qedit
if defined _args set _PSarg="""%~f0""" %_args:"="""% -qedit
set _PSarg=%_PSarg:'=''%
set "d1=$t=[AppDomain]::CurrentDomain.DefineDynamicAssembly(4, 1).DefineDynamicModule(2, $False).DefineType(0);"
set "d2=$t.DefinePInvokeMethod('GetStdHandle', 'kernel32.dll', 22, 1, [IntPtr], @([Int32]), 1, 3).SetImplementationFlags(128);"
set "d3=$t.DefinePInvokeMethod('SetConsoleMode', 'kernel32.dll', 22, 1, [Boolean], @([IntPtr], [Int32]), 1, 3).SetImplementationFlags(128);"
set "d4=$k=$t.CreateType(); $b=$k::SetConsoleMode($k::GetStdHandle(-10), 0x0080);"
setlocal EnableDelayedExpansion
%_psc% "!d1! !d2! !d3! !d4! & cmd.exe '/c' '!_PSarg!'" &exit /b
exit /b

:skipQE
set "logerr=%~dp0ErrorLog_V_%random%.txt"
set "_batf=%~f0"
set "_work=%~dp0"
set "_work=%_work:~0,-1%"
set _vdrv=%~d0
setlocal EnableDelayedExpansion
pushd "!_work!"
if exist "convert-UUP.cmd" (
for /f "tokens=2 delims==" %%# in ('findstr /i /b /c:"set _Debug" "convert-UUP.cmd"') do if not defined _udbg set _udbg=%%#
for /f "tokens=2 delims==" %%# in ('findstr /i /b /c:"@set uivr" "convert-UUP.cmd"') do if not defined _uver set _uver=%%#
)
if defined _udbg set _Debug=%_udbg%
if defined _uver set uivr=%_uver%

if %_Debug% equ 0 (
  set "_Nul1=1>nul"
  set "_Nul2=2>nul"
  set "_Nul6=2^>nul"
  set "_Nul3=1>nul 2>nul"
  set "_Pause=pause >nul"
  set "_Contn=echo 按任意键继续…… ===" 
  set "_Exit=echo 按任意键退出。" 
  set "_Supp="
  set "_Nul7=1>nul 2>nul"
  goto :Begin
)
  set "_Nul1="
  set "_Nul2="
  set "_Nul6="
  set "_Nul3="
  set "_Pause=rem."
  set "_Contn=rem."
  set "_Exit=rem."
  set "_Supp=1>nul"
  set "_Nul7="
@echo on
@prompt $G

:Begin
set "_dLog=%SystemRoot%\Logs\DISM"
call :checkadk
set _fils=(7z.dll,7z.exe,cdimage.exe,imagex.exe,libwim-15.dll,offlinereg.exe,offreg.dll,wimlib-imagex.exe,veData.cmd)
for %%# in %_fils% do (
if not exist ".\bin\%%#" (set _bin=%%#&goto :E_Bin)
)
set "_mount=%_vdrv%\MountUUP"
set "_ntf=NTFS"
if /i not "%_vdrv%"=="%SystemDrive%" if %_cwmi% equ 1 for /f "tokens=2 delims==" %%# in ('"wmic volume where DriveLetter='%_vdrv%' get FileSystem /value"') do set "_ntf=%%#"
if /i not "%_vdrv%"=="%SystemDrive%" if %_cwmi% equ 0 for /f %%# in ('%_psc% "(([WMISEARCHER]'Select * from Win32_Volume where DriveLetter=\"%_vdrv%\"').Get()).FileSystem"') do set "_ntf=%%#"
if /i not "%_ntf%"=="NTFS" (
set "_mount=%SystemDrive%\MountUUP"
)
set "_elProf=Enterprise,IoTEnterprise,IoTEnterpriseK,ServerRdsh,Education,ProfessionalEducation,ProfessionalWorkstation,CloudEdition"
set "_elProN=EnterpriseN,EducationN,ProfessionalEducationN,ProfessionalWorkstationN,CloudEditionN"
set "_elHome=CoreSingleLanguage"
set "_elLTSC=IoTEnterpriseS,IoTEnterpriseSK"
set "vEditions=%_elProf%,%_elProN%,%_elLTSC%,%_elHome%"
set ERRTEMP=
set _exDism=0
set _all=0
set _dir=0
set _dvd=0
set _iso=0
set "_ln2=____________________________________________________________"
set "_ln1=________________________________________________"
if not defined _type @color 07
if not exist "ConvertConfig.ini" goto :proceed
findstr /i \[create_virtual_editions\] ConvertConfig.ini %_Nul1% || goto :proceed
for %%# in (
UseDism
AutoStart
DeleteSource
Preserve
SkipISO
wim2esd
wim2swm
) do (
call :ReadINI %%#
)
findstr /b /i vAutoEditions ConvertConfig.ini %_Nul1% && for /f "tokens=1* delims==" %%A in ('findstr /b /i vAutoEditions ConvertConfig.ini') do set "AutoEditions=%%B"
findstr /b /i vSortEditions ConvertConfig.ini %_Nul1% && for /f "tokens=1* delims==" %%A in ('findstr /b /i vSortEditions ConvertConfig.ini') do set "SortEditions=%%B"
goto :proceed

:ReadINI
findstr /b /i v%1 ConvertConfig.ini %_Nul1% && for /f "tokens=2 delims==" %%# in ('findstr /b /i v%1 ConvertConfig.ini') do set "%1=%%#"
goto :eof

:proceed
if defined _args (
if /i "%_type%"=="autoswm" set _uupc=1&set AutoStart=1&set Preserve=0&set _Debug=1&set wim2esd=0&set wim2swm=1
if /i "%_type%"=="autowim" set _uupc=1&set AutoStart=1&set Preserve=0&set _Debug=1&set wim2esd=0&set wim2swm=0
if /i "%_type%"=="autoesd" set _uupc=1&set AutoStart=1&set Preserve=0&set _Debug=1&set wim2esd=1&set wim2swm=0
if /i "%_type%"=="manuswm" set wim2esd=0&set wim2swm=1
if /i "%_type%"=="manuwim" set wim2esd=0&set wim2swm=0
if /i "%_type%"=="manuesd" set wim2esd=1&set wim2swm=0
if /i "%_type%"=="extdism" set AutoStart=1&set Preserve=0&set _Debug=1&set _exDism=1&set _exEdtn=%2
)
if %_uupc% equ 1 if exist "ConvertConfig.ini" (
findstr /b /i SkipISO ConvertConfig.ini %_Nul1% && for /f "tokens=2 delims==" %%# in ('findstr /b /i SkipISO ConvertConfig.ini') do set "SkipISO=%%#"
)
if %_uupc% equ 1 if not exist "ConvertConfig.ini" (
for /f "tokens=2 delims==" %%# in ('findstr /i /b /c:"set SkipISO" "convert-UUP.cmd"') do if not defined _uiso (set _uiso=%%#&set SkipISO=%%#)
)
set _shortINF=
if %_exDism% equ 0 goto :checkdir

:extdism
:: call :dk_color1 %Blue% "=== 创建虚拟升级版本…… ===" 4 
set UseDism=1
set ISOdir=ISOUUP
set WimFile=install.wim
imagex /info ISOFOLDER\Sources\%WimFile% >bin\infoall.txt 2>&1
for /f "tokens=3 delims=: " %%# in ('findstr /i /b /c:"Image Count" bin\infoall.txt') do set images=%%#
for /l %%# in (1,1,%images%) do imagex /info ISOFOLDER\Sources\%WimFile% %%# >bin\info%%#.txt 2>&1
for /f "tokens=3 delims=<>" %%# in ('find /i "<BUILD>" bin\info1.txt') do set _build=%%#
set EditionHome=0
set EditionProf=0
set EditionProN=0
set EditionLTSC=0
set Edition%_exEdtn%=1
set _shortINF=1
call :sharedINF
goto :dCheck

:checkdir
title 虚拟升级版本 %uivr% 
dir /b /ad . %_Nul3% || goto :checkdvd
for /f "tokens=* delims=" %%# in ('dir /b /ad .') do (
if exist "%%~#\Sources\install.wim" set _dir=1&set "ISOdir=%%~#"
)
if %_dir% neq 1 for /f "tokens=* delims=" %%# in ('dir /b /ad .') do (
if exist "%%~#\Sources\install.esd" set _dir=1&set "ISOdir=%%~#"
)
if %_dir% neq 1 goto :checkdvd
goto :dCheck

:checkdvd
for %%# in (D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do (
if exist "%%#:\Sources\install.wim" set _dvd=1&set "ISOdir=%%#:"
)
if %_dvd% neq 1 for %%# in (D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do (
if exist "%%#:\Sources\install.esd" set _dvd=1&set "ISOdir=%%#:"
)
if %_dvd% neq 1 goto :checkiso
goto :dCheck

:checkiso
if exist "*.iso" for /f "tokens=* delims=" %%# in ('dir /b /a:-d *.iso') do (
set _iso+=1
set "ISOfile=%%~#"
)
if %_iso% equ 1 (
set Preserve=0
goto :dISO
)
if %_Debug% neq 0 goto :dCheck

:prompt
@cls
set _erriso=0
set ISOfile=
echo.
echo 输入 ISO 文件的完整路径 
echo %_ln1%
echo.
set /p ISOfile=
if not defined ISOfile set _Debug=1&goto :QUIT
set "ISOfile=%ISOfile:"=%"
if not exist "%ISOfile%" set _erriso=1
if /i not "%ISOfile:~-4%"==".iso" set _erriso=1
if %_erriso% equ 1 (
%_err%
echo 输入的路径不是有效的 ISO 文件 
echo.
%_Contn%&%_Pause%
goto :prompt
)
set _iso=1
set Preserve=0

:dISO
:: @color 1F
@cls
call :dk_color1 %Blue% "=== 解压 ISO 文件…… ===" 4 5 
echo "!ISOfile!"
set ISOdir=ISOUUP
if exist %ISOdir%\ rmdir /s /q %ISOdir%\
7z.exe x "!ISOfile!" -o%ISOdir% * -r %_Null%

:dCheck
if defined _Supp (
if defined _args echo "!_args!"
echo "!_work!"
)
if %_Debug% neq 0 (
if %AutoStart% equ 0 set AutoStart=1
)
if not defined ISOdir (
(echo.&echo ISOdir 源文件路径未指定，或者无效)>>"!logerr!" 
exit /b
)
if exist bin\temp\ rmdir /s /q bin\temp\
:: @color 1F
set _configured=0
for %%# in (
UseDism
AutoStart
DeleteSource
Preserve
SkipISO
wim2esd
wim2swm
) do (
if !%%#! neq 0 set _configured=1
)
if defined SortEditions set _configured=1
if %_exDism% equ 1 goto :AUTOMENU
if %_uupc% equ 1 (call :dk_color1 %Blue% "=== 创建虚拟升级版本…… ===" 4) else (call :dk_color1 %Blue% "=== 检查分发信息…… ===" 4) 
if %_dvd% equ 1 set Preserve=1
goto :dInfo

:AUTOMENU
if %AutoStart% equ 0 goto :MULTIMENU
if not defined AutoEditions (
set "AutoEditions=%vEditions%"
set "_showEd=ALL"
) else (
set "_showEd=%AutoEditions%"
)
for %%# in (%AutoEditions%) do (
if /i %%#==Enterprise if %EditionProf% equ 1 (set Enterprise=1)
if /i %%#==Education if %EditionProf% equ 1 (set Education=1)
if /i %%#==ProfessionalEducation if %EditionProf% equ 1 (set ProfessionalEducation=1)
if /i %%#==ProfessionalWorkstation if %EditionProf% equ 1 (set ProfessionalWorkstation=1)
if /i %%#==EnterpriseN if %EditionProN% equ 1 (set EnterpriseN=1)
if /i %%#==EducationN if %EditionProN% equ 1 (set EducationN=1)
if /i %%#==ProfessionalEducationN if %EditionProN% equ 1 (set ProfessionalEducationN=1)
if /i %%#==ProfessionalWorkstationN if %EditionProN% equ 1 (set ProfessionalWorkstationN=1)
if /i %%#==CoreSingleLanguage if %EditionHome% equ 1 (set CoreSingleLanguage=1)
if /i %%#==ServerRdsh if %EditionProf% equ 1 (set ServerRdsh=1)
if /i %%#==IoTEnterprise if %EditionProf% equ 1 if %_build% geq 18277 (set IoTEnterprise=1)
if /i %%#==IoTEnterpriseS if %EditionLTSC% equ 1 if %_build% geq 19041 (set IoTEnterpriseS=1)
if /i %%#==CloudEdition if %EditionProf% equ 1 if %_build% geq 21364 (set CloudEdition=1)
if /i %%#==CloudEditionN if %EditionProN% equ 1 if %_build% geq 21364 (set CloudEditionN=1)
if /i %%#==IoTEnterpriseK if %EditionProf% equ 1 if %_build% geq 25982 (set IoTEnterpriseK=1)
if /i %%#==IoTEnterpriseSK if %EditionLTSC% equ 1 if %_build% geq 25193 (set IoTEnterpriseSK=1)
)
goto :CREATEMENU

:SHWOINFO
echo.
for %%# in (%vEditions%) do (
set %%#=0
)
for %%# in (%vEditions%) do (
find /i "<EDITIONID>%%#</EDITIONID>" bin\infoall.txt %_Nul1% && set %%#=1
)
if %EditionProf% equ 1 (
if %Enterprise% equ 0 echo. 1. 企业版 
if %Education% equ 0 echo. 2. 教育版 
if %ProfessionalEducation% equ 0 echo. 3. 专业教育版 
if %ProfessionalWorkstation% equ 0 echo. 4. 专业工作站版 
)
if %EditionProN% equ 1 (
if %EnterpriseN% equ 0 echo. 5. 企业版 N 
if %EducationN% equ 0 echo. 6. 教育版 N 
if %ProfessionalEducationN% equ 0 echo. 7. 专业教育版 N 
if %ProfessionalWorkstationN% equ 0 echo. 8. 专业工作站版 N 
)
if %EditionHome% equ 1 (
if %CoreSingleLanguage% equ 0 echo. 9. 家庭单语言版 
)
if %EditionProf% equ 1 (
if %ServerRdsh% equ 0 echo 10. 企业版多会话 
if %IoTEnterprise% equ 0 if %_build% geq 18277 echo 11. IoT 企业版 {OEM} 
)
if %EditionLTSC% equ 1 (
if %IoTEnterpriseS% equ 0 if %_build% geq 19041 echo 12. IoT 企业版 LTSC {OEM} 
)
if %EditionProf% equ 1 (
if %CloudEdition% equ 0 if %_build% geq 21364 echo 13. SE [云版] 
)
if %EditionProN% equ 1 (
if %CloudEditionN% equ 0 if %_build% geq 21364 echo 14. SE N [云版 N] 
)
if %EditionProf% equ 1 (
if %IoTEnterpriseK% equ 0 if %_build% geq 25982 echo 15. IoT 企业版订阅 {OEM} 
)
if %EditionLTSC% equ 1 (
if %IoTEnterpriseSK% equ 0 if %_build% geq 25193 echo 16. IoT 企业版 LTSC 订阅 {OEM} 
)
exit /b

:chkinp
if %1 equ 1 if %EditionProf% equ 1 if %Enterprise% equ 0 (set Enterprise=1&set verify=1)
if %1 equ 2 if %EditionProf% equ 1 if %Education% equ 0 (set Education=1&set verify=1)
if %1 equ 3 if %EditionProf% equ 1 if %ProfessionalEducation% equ 0 (set ProfessionalEducation=1&set verify=1)
if %1 equ 4 if %EditionProf% equ 1 if %ProfessionalWorkstation% equ 0 (set ProfessionalWorkstation=1&set verify=1)
if %1 equ 5 if %EditionProN% equ 1 if %EnterpriseN% equ 0 (set EnterpriseN=1&set verify=1)
if %1 equ 6 if %EditionProN% equ 1 if %EducationN% equ 0 (set EducationN=1&set verify=1)
if %1 equ 7 if %EditionProN% equ 1 if %ProfessionalEducationN% equ 0 (set ProfessionalEducationN=1&set verify=1)
if %1 equ 8 if %EditionProN% equ 1 if %ProfessionalWorkstationN% equ 0 (set ProfessionalWorkstationN=1&set verify=1)
if %1 equ 9 if %EditionHome% equ 1 if %CoreSingleLanguage% equ 0 (set CoreSingleLanguage=1&set verify=1)
if %1 equ 10 if %EditionProf% equ 1 if %ServerRdsh% equ 0 (set ServerRdsh=1&set verify=1)
if %1 equ 11 if %EditionProf% equ 1 if %IoTEnterprise% equ 0 if %_build% geq 18277 (set IoTEnterprise=1&set verify=1)
if %1 equ 12 if %EditionLTSC% equ 1 if %IoTEnterpriseS% equ 0 if %_build% geq 19041 (set IoTEnterpriseS=1&set verify=1)
if %1 equ 13 if %EditionProf% equ 1 if %CloudEdition% equ 0 if %_build% geq 21364 (set CloudEdition=1&set verify=1)
if %1 equ 14 if %EditionProN% equ 1 if %CloudEditionN% equ 0 if %_build% geq 21364 (set CloudEditionN=1&set verify=1)
if %1 equ 15 if %EditionProf% equ 1 if %IoTEnterpriseK% equ 0 if %_build% geq 25982 (set IoTEnterpriseK=1&set verify=1)
if %1 equ 16 if %EditionLTSC% equ 1 if %IoTEnterpriseSK% equ 0 if %_build% geq 25193 (set IoTEnterpriseSK=1&set verify=1)
exit /b

:MULTIMENU
@cls
call :dk_color1 %Blue% "可用目标发行版本：" 
call :SHWOINFO
echo %_ln2%
echo.
echo 选项： 
echo. 1 - 创建组合发行版本 
echo. 2 - 创建单一发行版本 
if %_sum% gtr 2 echo. 3 - 创建随机选择的发行版本 
echo %_ln1%
echo.
choice /c 1230 /n /m "输入您的选择，或按 0 退出： " 
if errorlevel 4 (set _Debug=1&goto :QUIT)
if errorlevel 3 goto :RANDOMMENU
if errorlevel 2 goto :SINGLEMENU
if errorlevel 1 goto :ALLMENU
goto :MULTIMENU

:ALLMENU
if %EditionProf% equ 1 (
for %%# in (Enterprise,Education,ProfessionalEducation,ProfessionalWorkstation,ServerRdsh) do set %%#=1
if %_build% geq 18277 set IoTEnterprise=1
if %_build% geq 21364 set CloudEdition=1
if %_build% geq 25982 set IoTEnterpriseK=1
)
if %EditionProN% equ 1 (
for %%# in (EnterpriseN,EducationN,ProfessionalEducationN,ProfessionalWorkstationN) do set %%#=1
if %_build% geq 21364 set CloudEditionN=1
)
if %EditionLTSC% equ 1 (
if %_build% geq 19041 set IoTEnterpriseS=1
if %_build% geq 25193 set IoTEnterpriseSK=1
)
if %EditionHome% equ 1 (
set CoreSingleLanguage=1
)
goto :CREATEMENU

:SINGLEMENU
@cls
set verify=0
set _single=
call :SHWOINFO
echo %_ln2%
echo.
echo 输入发行版本代码开始创建镜像。或按‘0’返回 
echo %_ln1%
echo.
set /p _single= ^> 输入您的选择，并按下“Enter”键确认： 
if not defined _single (set _Debug=1&goto :QUIT)
if "%_single%"=="0" (set "_single="&goto :MULTIMENU)
call :chkinp %_single%
if %verify% equ 1 goto :CREATEMENU
set _single=
goto :SINGLEMENU

:RANDOMMENU
@cls
set verify=0
set _count=
set _index=
call :SHWOINFO
echo %_ln2%
echo.
echo 输入要处理的非连续发行版本编号。使用空格分隔，或者输入‘0’返回 
echo 例如：1 3 4 或者 5 1 或者 4 2 10 
echo %_ln1%
echo.
set /p _index= ^> 输入您的选择，并按下“Enter”键确认： 
if not defined _index (set _Debug=1&goto :QUIT)
if "%_index%"=="0" (set "_index="&goto :MULTIMENU)
for %%# in (%_index%) do (
call :chkinp %%#
)
if %verify% equ 1 goto :CREATEMENU
set _index=
goto :RANDOMMENU

:CREATEMENU
set modded=0
set _preMount=0
set _preCopy=4
set _sufCopy=
if %AutoStart% equ 0 (
@cls
call :checkQE
)
if %_exDism% equ 0 if %_configured% equ 1 (
set _preMount=0
set _preCopy=0
set _sufCopy=5
call :dk_color1 %Blue% "=== 当前选项 ===" 4 5 
  for %%# in (
  UseDism
  AutoStart
  DeleteSource
  Preserve
  SkipISO
  wim2esd
  wim2swm
  ) do (
  if !%%#! neq 0 echo %%#
  )
if %AutoStart% neq 0 if defined AutoEditions echo 自动发行版本： %_showEd% 
if defined SortEditions echo 排序发行版本： %SortEditions% 
echo.
)
if %_exDism% equ 1 goto :skipcopy

if %winbuild% lss 10240 if %_ADK% equ 0 (
if %UseDism% neq 0 call :dk_color1 %_Yellow% "未检测到 Windows NT 10.0 ADK，将还原为注册表方法。" 0 5 
set UseDism=0
)
if %winbuild% lss 9600 (
if %UseDism% equ 2 (set UseDism=1) else (set UseDism=0)
)
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
if %Preserve% neq 0 (
call :dk_color1 %Blue% "=== 复制源文件： {%ISOdir%} ===" %_preCopy% %_sufCopy% 
robocopy "%ISOdir%" "ISOFOLDER" /E /A-:R %_Null%
) else (
move /y "%ISOdir%" ISOFOLDER %_Nul1%
attrib -A -I -R "ISOFOLDER\*" /S /D %_Nul3%
)
if not exist "ISOFOLDER\Sources\%WimFile%" (
%_err%
echo 创建 ISOFOLDER\Sources\%WimFile% 失败 
echo.
(echo.&echo 创建 ISOFOLDER\Sources\%WimFile% 失败)>>"!logerr!" 
goto :E_None
)

:skipcopy
for %%# in (%vEditions%) do (
find /i "<EDITIONID>%%#</EDITIONID>" bin\infoall.txt %_Nul1% && set %%#=0
)
for %%# in (%vEditions%) do (
if !%%#! equ 1 set /a _all+=1
)
if %_all% equ 0 goto :E_None
set _doProf=0
set _doProN=0
set _doHome=0
set _doLTSC=0
if %EditionProf% equ 1 for %%# in (%_elProf%) do (
if !%%#! equ 1 set _doProf=1
)
if %EditionProN% equ 1 for %%# in (%_elProN%) do (
if !%%#! equ 1 set _doProN=1
)
if %EditionLTSC% equ 1 for %%# in (%_elLTSC%) do (
if !%%#! equ 1 set _doLTSC=1
)
if %EditionHome% equ 1 for %%# in (%_elHome%) do (
if !%%#! equ 1 set _doHome=1
)
set /a _doALL=%_doProf%+%_doProN%+%_doHome%+%_doLTSC%
set /a index=0
if %UseDism% equ 1 (
set /a index=%images%
goto :doDism
)
set _doCopy=0
if %DeleteSource% neq 1 set _doCopy=1
if %_doALL% lss %images% set _doCopy=1
if %_doCopy% equ 1 (
call :dk_color1 %Blue% "=== 复制 %WIMFILE% 映像…… ===" %_preCopy% 
copy /y ISOFOLDER\Sources\%WimFile% ISOFOLDER\Sources\temp.wim %_Nul1%
set /a index=%images%
)
:: for %%# in (%vEditions%) do (
:: if !%%#! equ 1 call :doData %%#
:: )
if %_doProf% equ 1 for %%# in (%_elProf%) do (
if !%%#! equ 1 call :doData %%#
)
if %_doProN% equ 1 for %%# in (%_elProN%) do (
if !%%#! equ 1 call :doData %%#
)
if %_doLTSC% equ 1 for %%# in (%_elLTSC%) do (
if !%%#! equ 1 call :doData %%#
)
if %_doHome% equ 1 for %%# in (%_elHome%) do (
if !%%#! equ 1 call :doData %%#
)
if %modded% equ 1 (goto :ISOCREATE) else (goto :E_None)

:doDism
if %_exDism% equ 0 del /f /q "%_dLog%\DismVirtualEditions.log" %_Nul3%
if not exist "%_dLog%\" mkdir "%_dLog%" %_Nul3%
if %_build% geq 19041 if %winbuild% lss 17133 if not exist "%SysPath%\ext-ms-win-security-slc-l1-1-0.dll" (
copy /y %SysPath%\slc.dll %SysPath%\ext-ms-win-security-slc-l1-1-0.dll %_Nul1%
if /i not %xOS%==x86 copy /y %SystemRoot%\SysWOW64\slc.dll %SystemRoot%\SysWOW64\ext-ms-win-security-slc-l1-1-0.dll %_Nul1%
)
if %_doProf% equ 1 (
call :doMount %IndexProf%
for %%# in (%_elProf%) do (if !%%#! equ 1 call :doData %%#)
call :doUnmount %IndexProf%
)
if defined _term exit /b
if %_doProN% equ 1 (
call :doMount %IndexProN%
for %%# in (%_elProN%) do (if !%%#! equ 1 call :doData %%#)
call :doUnmount %IndexProN%
)
if defined _term exit /b
if %_doLTSC% equ 1 (
call :doMount %IndexLTSC%
for %%# in (%_elLTSC%) do (if !%%#! equ 1 call :doData %%#)
call :doUnmount %IndexLTSC%
)
if defined _term exit /b
if %_doHome% equ 1 (
call :doMount %IndexHome%
for %%# in (%_elHome%) do (if !%%#! equ 1 call :doData %%#)
call :doUnmount %IndexHome%
)
if defined _term exit /b
if %_exDism% equ 1 exit /b
if %_build% geq 19041 if %winbuild% lss 17133 if exist "%SysPath%\ext-ms-win-security-slc-l1-1-0.dll" (
del /f /q %SysPath%\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
if /i not %xOS%==x86 del /f /q %SystemRoot%\SysWOW64\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
)
if %modded% equ 1 (goto :ISOCREATE) else (goto :E_None)

:doData
if defined _term exit /b
if /i %1==IoTEnterpriseSK (
if %_build% lss 25193 exit /b
)
if /i %1==IoTEnterpriseK (
if %_build% lss 25982 exit /b
)
if /i %1==IoTEnterpriseS (
if %_build% lss 19041 exit /b
if %UseDism% equ 1 if not exist "%_mount%\Windows\System32\spp\tokens\skus\IoTEnterpriseS\IoTEnterpriseS-OEM*.xrm-ms" exit /b
)
if /i %1==IoTEnterprise (
if %_build% lss 18277 exit /b
)
if /i %1==CloudEdition (
if %_build% lss 21364 exit /b
)
if /i %1==CloudEditionN (
if %_build% lss 21364 exit /b
)
call bin\veData.cmd %1
call :WIM
exit /b

:WIM
if defined _term exit /b
call :dk_color1 %Gray% "=== 创建发行版本： %desc% ===" 4 
if %UseDism% equ 1 goto :doWIM
echo.
if %DeleteSource% equ 1 (
  if %_all% equ 1 (
    if %images% equ 1 (
    ren ISOFOLDER\Sources\%WimFile% temp.wim
    wimlib-imagex.exe info ISOFOLDER\Sources\temp.wim 1 "%winver% %desc%" "%winver% %desc%" %_Null%
    )
    if %images% neq 1 (
    wimlib-imagex.exe export ISOFOLDER\Sources\%WimFile% %source% ISOFOLDER\Sources\temp.wim "%winver% %desc%" "%winver% %desc%"
    )
  )
  if %_all% neq 1 (
  wimlib-imagex.exe export ISOFOLDER\Sources\%WimFile% %source% ISOFOLDER\Sources\temp.wim "%winver% %desc%" "%winver% %desc%"
  )
)
if %DeleteSource% neq 1 (
wimlib-imagex.exe export ISOFOLDER\Sources\%WimFile% %source% ISOFOLDER\Sources\temp.wim "%winver% %desc%" "%winver% %desc%"
)
set /a index+=1
wimlib-imagex.exe extract ISOFOLDER\Sources\temp.wim %index% \Windows\System32\config\SOFTWARE \Windows\System32\config\SYSTEM \Windows\servicing\Editions\%EditionID%Edition.xml --dest-dir=.\bin\temp --no-acls --no-attributes %_Null%
%_Nul3% reg.exe load HKLM\SOF .\bin\temp\SOFTWARE
%_Nul3% reg.exe load HKLM\SYS .\bin\temp\SYSTEM
for %%# in (EditionID,ProductId) do (
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows NT\CurrentVersion" /f /v %%# /t REG_SZ /d !%%#!
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows NT\CurrentVersion\DefaultProductKey2" /f /v %%# /t REG_SZ /d !%%#!
)
for %%# in (DigitalProductId,DigitalProductId4) do (
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows NT\CurrentVersion" /f /v %%# /t REG_BINARY /d !%%#!
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows NT\CurrentVersion\DefaultProductKey2" /f /v %%# /t REG_BINARY /d !%%#!
)
for %%# in (OSProductContentId,OSProductPfn) do (
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows NT\CurrentVersion\DefaultProductKey2" /f /v %%# /t REG_SZ /d !%%#!
%_Nul3% reg.exe add "HKLM\SYS\ControlSet001\Control\ProductOptions" /f /v %%# /t REG_SZ /d !%%#!
)
if /i %EditionID%==CoreSingleLanguage (
%_Nul3% reg.exe add "HKLM\SYS\ControlSet001\Services\LanmanWorkstation\Parameters" /f /v AllowInsecureGuestAuth /t REG_DWORD /d !Insecure!
) else if %_build% lss 18362 (
%_Nul3% reg.exe add "HKLM\SYS\ControlSet001\Services\LanmanWorkstation\Parameters" /f /v AllowInsecureGuestAuth /t REG_DWORD /d !Insecure!
)
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows NT\CurrentVersion\Print" /f /v DoNotInstallCompatibleDriverFromWindowsUpdate /t REG_DWORD /d !Print!
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows\CurrentVersion\Setup\OOBE" /f /v SetupDisplayedProductKey /t REG_DWORD /d 1
if %_build% geq 22557 (
%_Nul3% reg.exe add "HKLM\SOF\Microsoft\Windows\Windows Error Reporting" /f /v ChangeDumpTypeByTelemetryLevel /t REG_DWORD /d !DumpLv!
)
if /i %EditionID%==ServerRdsh (
%_Nul3% reg.exe add "HKLM\SYS\Setup\FirstBoot\PreOobe" /f /v 00 /t REG_SZ /d "cmd.exe /c powershell -ep unrestricted -nop -c \"Set-CimInstance -Query 'Select * from Win32_UserAccount WHERE SID LIKE ''S-1-5-21-%%-500''' -Property @{Disabled=0}\" &exit /b 0 "
)
%_Nul3% reg.exe unload HKLM\SYS
%_Nul3% reg.exe save HKLM\SOF .\bin\temp\SOFTWARE2 /y
%_Nul3% reg.exe unload HKLM\SOF
%_Nul3% move /y .\bin\temp\SOFTWARE2 .\bin\temp\SOFTWARE
type nul>bin\temp\virtual.txt
>>bin\temp\virtual.txt echo add 'bin^\temp^\SOFTWARE' '^\Windows^\System32^\config^\SOFTWARE'
>>bin\temp\virtual.txt echo add 'bin^\temp^\SYSTEM' '^\Windows^\System32^\config^\SYSTEM'
>>bin\temp\virtual.txt echo add 'bin^\temp^\%EditionID%Edition.xml' '^\Windows^\%EditionID%.xml'
wimlib-imagex.exe update ISOFOLDER\Sources\temp.wim %index% < bin\temp\virtual.txt %_Null%
rmdir /s /q bin\temp\
:: echo.
wimlib-imagex.exe info ISOFOLDER\Sources\temp.wim %index% --image-property WINDOWS/EDITIONID=%EditionID% --image-property FLAGS=%EditionID% --image-property DISPLAYNAME="%winver% %desc%" --image-property DISPLAYDESCRIPTION="%winver% %desc%"
set modded=1
exit /b

:doWIM
set "_chn=/Channel:%channel%"
if /i "%channel%"=="OEM" set "_chn="
if %_build% equ 18362 set "_chn="
call :wds_add
%_dism1% /Image:"%_mount%" /LogPath:"%_dLog%\DismVirtualEditions.log" /Set-Edition:%EditionID% %_chn%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 (
call :dk_color1 %Red% "设置 %EditionID% 发行版本失败。" 4 
(echo.&echo 设置 %EditionID% 发行版本失败。)>>"!logerr!" 
exit /b
)
if /i %EditionID%==ServerRdsh (
%_Nul3% reg.exe load HKLM\SYS "%_mount%\Windows\System32\config\SYSTEM"
%_Nul3% reg.exe add "HKLM\SYS\Setup\FirstBoot\PreOobe" /f /v 00 /t REG_SZ /d "cmd.exe /c powershell -ep unrestricted -nop -c \"Set-CimInstance -Query 'Select * from Win32_UserAccount WHERE SID LIKE ''S-1-5-21-%%-500''' -Property @{Disabled=0}\" &exit /b 0 "
%_Nul3% reg.exe unload HKLM\SYS
)
call :wds_rem
%_dism1% /Commit-Image /MountDir:"%_mount%" /Append %_Supp%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 (
call :dk_color1 %Red% "保存发行版本映像失败。" 4 
(echo.&echo 保存发行版本映像失败。)>>"!logerr!" 
exit /b
)
set /a index+=1
if %_exDism% equ 0 (
set "_Nul7="
echo.
)
%_Nul7% wimlib-imagex.exe info ISOFOLDER\Sources\%WimFile% %index% "%winver% %desc%" "%winver% %desc%" --image-property FLAGS=%EditionID% --image-property DISPLAYNAME="%winver% %desc%" --image-property DISPLAYDESCRIPTION="%winver% %desc%"
set modded=1
exit /b

:doMount
if defined _term exit /b
if %_exDism% equ 1 exit /b
call :dk_color1 %Blue% "=== 挂载源映像索引： %1 ===" %_preMount% 
set _preMount=4
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if not exist "%_mount%\" mkdir "%_mount%"
%_dism1% /Mount-Wim /Wimfile:ISOFOLDER\Sources\%WimFile% /Index:%1 /MountDir:"%_mount%" %_Supp%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 (
call :discard
set "MESSAGE=挂载映像失败"&goto :E_MSG 
)
exit /b

:doUnmount
if defined _term exit /b
if %_exDism% equ 1 exit /b
call :dk_color1 %Blue% "=== 卸载源映像索引： %1 ===" 4 
%_dism1% /Unmount-Wim /MountDir:"%_mount%" /Discard %_Supp%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 (
call :discard
set "MESSAGE=卸载映像失败"&goto :E_MSG 
)
rmdir /s /q "%_mount%\"
exit /b

:discard
%_dism1% /Image:"%_mount%" /Get-Packages %_Null%
%_dism1% /Unmount-Wim /MountDir:"%_mount%" /Discard %_Supp%
%_dism1% /Cleanup-Mountpoints %_Nul3%
%_dism1% /Cleanup-Wim %_Nul3%
if exist "%_mount%\" rmdir /s /q "%_mount%\"
set _term=1
exit /b

:wds_add
if %_build% geq 29550 if %winbuild% lss 20348 if /i not %xOS%==x86 (
if /i %arch%==%xOS% copy /y %SysPath%\wdscore.dll "%_mount%\Windows\System32\downlevel\" %_Nul1%
if /i %arch%==x64 if /i %xOS%==amd64 copy /y %SysPath%\wdscore.dll "%_mount%\Windows\System32\downlevel\" %_Nul1%
if exist "%SystemRoot%\SysWOW64\wdscore.dll" if exist "%_mount%\Windows\SysWOW64\downlevel\*.dll" copy /y %SystemRoot%\SysWOW64\wdscore.dll "%_mount%\Windows\SysWOW64\downlevel\" %_Nul1%
)
exit /b

:wds_rem
if exist "%_mount%\Windows\System32\downlevel\wdscore.dll" del /f /q "%_mount%\Windows\System32\downlevel\wdscore.dll" %_Nul3%
if exist "%_mount%\Windows\SysWOW64\downlevel\wdscore.dll" del /f /q "%_mount%\Windows\SysWOW64\downlevel\wdscore.dll" %_Nul3%
exit /b

:ISOCREATE
if %UseDism% neq 1 (
if exist ISOFOLDER\Sources\%WimFile% del /f /q ISOFOLDER\Sources\%WimFile%
ren ISOFOLDER\Sources\temp.wim %WimFile%
)
for /f "tokens=3 delims=: " %%# in ('imagex /info ISOFOLDER\Sources\%WimFile% ^|findstr /i /b /c:"Image Count"') do set finalimages=%%#
if %finalimages% gtr 1 if not exist "ei.cfg" if not exist "UUPs\ei.cfg" if exist ISOFOLDER\Sources\ei.cfg del /f /q ISOFOLDER\Sources\ei.cfg
if %DeleteSource% equ 1 (
call :dk_color1 %Blue% "=== 删除源发行版本…… ===" 4 5 
if %_doProf% equ 1 call :dDelete Professional
if %_doProN% equ 1 call :dDelete ProfessionalN
if %_doLTSC% equ 1 call :dDelete EnterpriseS
if %_doHome% equ 1 call :dDelete Core
call :dPREPARE
)
if defined SortEditions if %finalimages% gtr 1 (
call :dk_color1 %Blue% "=== 排序发行版本…… ===" 4 5 
call :doSort
)
if not defined didsort if %wim2esd% equ 0 (
call :dk_color1 %Blue% "=== 重建 %WIMFILE% 映像…… ===" 4 5 
%_wrb% wimlib-imagex.exe optimize ISOFOLDER\Sources\%WimFile% %_Supp%
)
pushd "ISOFOLDER\Sources"
for /f %%# in ('dir /b /a:-d %WimFile%') do set "_size=000000%%~z#"
popd
if "%_size%" lss "0000004194304000" set wim2swm=0
if %wim2esd% equ 0 if %wim2swm% equ 0 goto :finVIR
if %wim2esd% equ 0 if %wim2swm% equ 1 goto :swmVIR
call :dk_color1 %Blue% "=== 转换 install.wim 至 install.esd…… ===" 4 5 
wimlib-imagex.exe export ISOFOLDER\Sources\install.wim all ISOFOLDER\Sources\install.esd --compress=LZMS --solid %_Supp%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 (
call :dk_color1 %Red% "在拆分映像时出错。install.esd 丢弃中" 4 
(echo.&echo 在拆分映像时出错。丢弃 install.esd)>>"!logerr!" 
del /f /q ISOFOLDER\Sources\install.esd %_Nul3%
)
if exist ISOFOLDER\Sources\install.esd del /f /q ISOFOLDER\Sources\install.wim
goto :finVIR
:swmVIR
call :dk_color1 %Blue% "=== 拆分 install.wim 为 install*.swm…… ===" 4 5 
wimlib-imagex.exe split ISOFOLDER\Sources\install.wim ISOFOLDER\Sources\install.swm 3500 %_Supp%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 (
call :dk_color1 %Red% "在拆分映像时出错。install*.swm 丢弃中" 4 
(echo.&echo 在拆分映像时出错。丢弃 install*.swm)>>"!logerr!" 
del /f /q ISOFOLDER\Sources\install*.swm %_Nul3%
)
if exist ISOFOLDER\Sources\install*.swm del /f /q ISOFOLDER\Sources\install.wim
:finVIR
if %SkipISO% neq 0 (
  ren ISOFOLDER %DVDISO%
  set qmsg=已完成。你已选择不创建 iso 文件。 
  goto :QUIT
)
call :dk_color1 %Blue% "=== 写入文件至 ISO 镜像…… ===" 4 
if defined _exTime set isotime=%_exTime%
if /i not %arch%==arm64 (
cdimage.exe -bootdata:2#p0,e,b"ISOFOLDER\boot\etfsboot.com"#pEF,e,b"ISOFOLDER\efi\Microsoft\boot\efisys.bin" -o -m -u2 -udfver102 -t%isotime% -l%DVDLABEL% ISOFOLDER %DVDISO%.ISO
) else (
cdimage.exe -bootdata:1#pEF,e,b"ISOFOLDER\efi\Microsoft\boot\efisys.bin" -o -m -u2 -udfver102 -t%isotime% -l%DVDLABEL% ISOFOLDER %DVDISO%.ISO
)
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 goto :E_ISO
set qmsg=已完成。 
goto :QUIT

:dDelete
for /f "tokens=3 delims=: " %%# in ('imagex /info ISOFOLDER\Sources\%WimFile% ^|findstr /i /b /c:"Image Count"') do set dimages=%%#
for /l %%# in (1,1,%dimages%) do imagex /info ISOFOLDER\Sources\%WimFile% %%# >bin\info%%#.txt 2>&1
for /L %%# in (1,1,%dimages%) do (
find /i "<EDITIONID>%1</EDITIONID>" bin\info%%#.txt %_Nul3% && (
  echo %1
  rem %_dism1% /Delete-Image /ImageFile:ISOFOLDER\Sources\%WimFile% /Index:%%#
  wimlib-imagex.exe delete ISOFOLDER\Sources\%WimFile% %%# --soft %_Nul3%
  )
)
del /f /q bin\info*.txt %_Nul3%
exit /b

:doSort
set simages=%finalimages%
for /l %%# in (1,1,%simages%) do imagex /info ISOFOLDER\Sources\%WimFile% %%# >bin\info%%#.txt 2>&1
set tcount=0
for %%A in (%SortEditions%) do (
for /L %%# in (1,1,%simages%) do (
  find /i "<EDITIONID>%%A</EDITIONID>" bin\info%%#.txt %_Nul3% && (
    set /a tcount+=1
    echo !tcount!. %%A
    wimlib-imagex.exe export ISOFOLDER\Sources\%WimFile% %%# ISOFOLDER\Sources\temp.wim %_Supp%
    )
  )
)
del /f /q bin\info*.txt %_Nul3%
if exist ISOFOLDER\Sources\temp.wim (
del /f /q ISOFOLDER\Sources\%WimFile%
ren ISOFOLDER\Sources\temp.wim %WimFile%
set didsort=1
)
exit /b

:dInfo
if exist "%ISOdir%\Sources\install.wim" (set WimFile=install.wim) else (set WimFile=install.esd&set wim2esd=0&set wim2swm=0&set UseDism=0)
imagex /info "%ISOdir%\Sources\%WimFile%" | findstr /i /c:"LZMS" %_Nul1% && (set wim2esd=0&set wim2swm=0&set UseDism=0)
wimlib-imagex.exe info "%ISOdir%\Sources\%WimFile%" 1 %_Nul3%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 (
%_err%
echo 执行 wimlib-imagex.exe 失败 
echo 请迁移到路径不含特殊字符的工作区 
echo.
(echo.&echo 执行 wimlib-imagex.exe 失败)>>"!logerr!" 
goto :QUIT
)
imagex /info "%ISOdir%\Sources\%WimFile%">bin\infoall.txt 2>&1
for /f "tokens=3 delims=: " %%# in ('findstr /i /b /c:"Image Count" bin\infoall.txt') do set images=%%#
for /l %%# in (1,1,%images%) do imagex /info "%ISOdir%\Sources\%WimFile%" %%# >bin\info%%#.txt 2>&1
for /f "tokens=3 delims=<>" %%# in ('find /i "<BUILD>" bin\info1.txt') do set _build=%%#
for /f "tokens=3 delims=<>" %%# in ('find /i "<DEFAULT>" bin\info1.txt') do set "langid=%%#"
for /f "tokens=3 delims=<>" %%# in ('find /i "<ARCH>" bin\info1.txt') do (if %%# equ 0 (set "arch=x86") else if %%# equ 9 (set "arch=x64") else (set "arch=arm64"))
set EditionHome=0
set EditionProf=0
set EditionProN=0
set EditionLTSC=0
find /i "Core</EDITIONID>" bin\infoall.txt %_Nul1% && (set EditionHome=1)
find /i "Professional</EDITIONID>" bin\infoall.txt %_Nul1% && (set EditionProf=1)
find /i "ProfessionalN</EDITIONID>" bin\infoall.txt %_Nul1% && (set EditionProN=1)
if %_build% geq 19041 (
find /i "<EDITIONID>EnterpriseS</EDITIONID>" bin\infoall.txt %_Nul1% && (set EditionLTSC=1)
)
:sharedINF
for /L %%# in (1,1,%images%) do (
if %EditionHome% equ 1 (find /i "Core</EDITIONID>" bin\info%%#.txt %_Nul3% && (set IndexHome=%%#))
if %EditionProf% equ 1 (find /i "Professional</EDITIONID>" bin\info%%#.txt %_Nul3% && (set IndexProf=%%#))
if %EditionProN% equ 1 (find /i "ProfessionalN</EDITIONID>" bin\info%%#.txt %_Nul3% && (set IndexProN=%%#))
if %EditionLTSC% equ 1 (find /i "<EDITIONID>EnterpriseS</EDITIONID>" bin\info%%#.txt %_Nul3% && (set IndexLTSC=%%#))
)
set "wtxHome=Windows 10"
set "wtxProf=Windows 10"
set "wtxProN=Windows 10"
set "wtxLTSC=Windows 10"
if %EditionHome% equ 1 (
find /i "<NAME>" bin\info%IndexHome%.txt %_Nul2% | find /i "Windows 11" %_Nul1% && (set "wtxHome=Windows 11")
find /i "<NAME>" bin\info%IndexHome%.txt %_Nul2% | find /i "Windows 12" %_Nul1% && (set "wtxHome=Windows 12")
)
if %EditionProf% equ 1 (
find /i "<NAME>" bin\info%IndexProf%.txt %_Nul2% | find /i "Windows 11" %_Nul1% && (set "wtxProf=Windows 11")
find /i "<NAME>" bin\info%IndexProf%.txt %_Nul2% | find /i "Windows 12" %_Nul1% && (set "wtxProf=Windows 12")
)
if %EditionProN% equ 1 (
find /i "<NAME>" bin\info%IndexProN%.txt %_Nul2% | find /i "Windows 11" %_Nul1% && (set "wtxProN=Windows 11")
find /i "<NAME>" bin\info%IndexProN%.txt %_Nul2% | find /i "Windows 12" %_Nul1% && (set "wtxProN=Windows 12")
)
if %EditionLTSC% equ 1 (
find /i "<NAME>" bin\info%IndexLTSC%.txt %_Nul2% | find /i "Windows 11" %_Nul1% && (set "wtxLTSC=Windows 11")
find /i "<NAME>" bin\info%IndexLTSC%.txt %_Nul2% | find /i "Windows 12" %_Nul1% && (set "wtxLTSC=Windows 12")
)
for /l %%# in (1,1,%images%) do del /f /q bin\info%%#.txt %_Nul3%
if defined _shortINF goto :eof
if %_build% lss 17063 (
if %_iso% equ 1 rmdir /s /q "%ISOdir%\"
set "MESSAGE=ISO 内部版本 %_build% 不支持虚拟升级版本"&goto :E_MSG 
)
if %EditionHome% equ 0 if %EditionProf% equ 0 if %EditionProN% equ 0 if %EditionLTSC% equ 0 (
if %_iso% equ 1 rmdir /s /q "%ISOdir%\"
set "MESSAGE=未检测到受支持的源发行版本"&goto :E_MSG 
)
if %EditionProf% equ 1 set /a _sum+=5
if %EditionProN% equ 1 set /a _sum+=4
if %EditionHome% equ 1 set /a _sum+=1
if %EditionLTSC% equ 1 if %_build% geq 19041 set /a _sum+=1
if %EditionProf% equ 1 if %_build% geq 18277 set /a _sum+=1
if %EditionProf% equ 1 if %_build% geq 21364 set /a _sum+=1
if %EditionProN% equ 1 if %_build% geq 21364 set /a _sum+=1
if %EditionProf% equ 1 if %_build% geq 25982 set /a _sum+=1
if %EditionLTSC% equ 1 if %_build% geq 25193 set /a _sum+=1
wimlib-imagex.exe extract "%ISOdir%\Sources\boot.wim" 2 sources\setuphost.exe --dest-dir=.\bin\temp --no-acls --no-attributes %_Null%
7z.exe l .\bin\temp\setuphost.exe >.\bin\temp\version.txt 2>&1
for /f "tokens=4-7 delims=.() " %%i in ('"findstr /i /b "FileVersion" .\bin\temp\version.txt" %_Nul6%') do (set uupver=%%i.%%j&set uupmaj=%%i&set uupmin=%%j&set branch=%%k&set uupdate=%%l&set bkpdate=%%l)
set revver=%uupver%&set revmaj=%uupmaj%&set revmin=%uupmin%
set "tok=6,7"&set "toe=5,6,7"
if /i %arch%==x86 (set _ss=x86) else if /i %arch%==x64 (set _ss=amd64) else (set _ss=arm64)
wimlib-imagex.exe extract "%ISOdir%\Sources\%WimFile%" 1 Windows\WinSxS\Manifests\%_ss%_microsoft-windows-coreos-revision*.manifest --dest-dir=.\bin\temp --no-acls --no-attributes %_Nul3%
if exist "bin\temp\*_microsoft-windows-coreos-revision*.manifest" for /f "tokens=%tok% delims=_." %%A in ('dir /b /a:-d /od .\bin\temp\*_microsoft-windows-coreos-revision*.manifest') do set revver=%%A.%%B&set revmaj=%%A&set revmin=%%B
if %_build% geq 15063 (
wimlib-imagex.exe extract "%ISOdir%\Sources\%WimFile%" 1 Windows\System32\config\SOFTWARE --dest-dir=.\bin\temp --no-acls --no-attributes %_Null%
set "isokey=Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\Installed"
for /f %%i in ('"offlinereg.exe .\bin\temp\SOFTWARE "!isokey!" enumkeys %_Nul6% ^| findstr /i /r "Client\.OS Server\.OS""') do if not errorlevel 1 (
  for /f "tokens=3 delims==:" %%A in ('"offlinereg.exe .\bin\temp\SOFTWARE "!isokey!\%%i" getvalue Branch %_Nul6%"') do set "revbranch=%%~A"
  for /f "tokens=5,6 delims==:." %%A in ('"offlinereg.exe .\bin\temp\SOFTWARE "!isokey!\%%i" getvalue Version %_Nul6%"') do if %%A gtr !revmaj! (
    set "revver=%%~A.%%B
    set revmaj=%%~A
    set "revmin=%%B
    )
  )
)
set chkmin=%revmin%
call :setuphostprep
for /f "tokens=4-7 delims=.() " %%i in ('"findstr /i /b "FileVersion" .\bin\version.txt" %_Nul6%') do (set uupver=%%i.%%j&set uupmaj=%%i&set uupmin=%%j&set branch=%%k&set uupdate=%%l)
del /f /q .\bin\version.txt %_Nul3%
set "isotime=!uupdate:~2,2!/!uupdate:~4,2!/20!uupdate:~0,2!,!uupdate:~7,2!:!uupdate:~9,2!:10"
set _pkgtime=0
if /i "%branch%"=="WinBuild" set _pkgtime=1
if /i "%branch%"=="GitEnlistment" set _pkgtime=1
if /i "%uupdate%"=="winpbld" set _pkgtime=1
if /i "%uupdate%"=="160101" set _pkgtime=1
echo %uupdate% | findstr /i "BldB" %_Nul1% && set _pkgtime=1
if %_pkgtime% equ 1 (
call :get_lcu_pkg
)
if defined revbranch set branch=%revbranch%
if %revmaj%==18363 (
if /i "%branch:~0,4%"=="19h1" set branch=19h2%branch:~4%
if %uupver:~0,5%==18362 set uupver=18363%uupver:~5%
)
if %revmaj%==19042 (
if /i "%branch:~0,2%"=="vb" set branch=20h2%branch:~2%
if %uupver:~0,5%==19041 set uupver=19042%uupver:~5%
)
if %revmaj%==19043 (
if /i "%branch:~0,2%"=="vb" set branch=21h1%branch:~2%
if %uupver:~0,5%==19041 set uupver=19043%uupver:~5%
)
if %revmaj%==19044 (
if /i "%branch:~0,2%"=="vb" set branch=21h2%branch:~2%
if %uupver:~0,5%==19041 set uupver=19044%uupver:~5%
)
if %revmaj%==19045 (
if /i "%branch:~0,2%"=="vb" set branch=22h2%branch:~2%
if %uupver:~0,5%==19041 set uupver=19045%uupver:~5%
)
if %revmaj% geq %_build% if %_build% geq 21382 (
if %uupver:~0,5%==%_build% set uupver=%revmaj%%uupver:~5%
)
if %revmaj%==22631 (
if /i "%branch:~0,2%"=="ni" (echo %branch% | find /i "beta" %_Nul1% || set branch=23h2_ni%branch:~2%)
if %uupver:~0,5%==22621 set uupver=22631%uupver:~5%
)
if %revmaj%==22635 (
if %uupver:~0,5%==22621 set uupver=22635%uupver:~5%
)
if %uupmin% lss %revmin% (
set uupver=%revver%
set uupmin=%revmin%
if not exist "%SystemRoot%\temp\" mkdir "%SystemRoot%\temp" %_Nul3%
wimlib-imagex.exe extract "%ISOdir%\Sources\%WimFile%" 1 Windows\Servicing\Packages\Package_for_RollupFix*.mum --dest-dir=.\bin\temp --no-acls --no-attributes %_Nul3%
for /f %%# in ('dir /b /a:-d /od bin\temp\Package_for_RollupFix*.mum') do copy /y "bin\temp\%%#" %SystemRoot%\temp\update.mum %_Nul1%
call :datemum uupdate isotime
)
if %uupmin% gtr %revmin% (
if not exist "%SystemRoot%\temp\" mkdir "%SystemRoot%\temp" %_Nul3%
wimlib-imagex.exe extract "%ISOdir%\Sources\%WimFile%" 1 Windows\servicing\Packages\Package_for_RollupFix*.mum --dest-dir=%SystemRoot%\temp --no-acls --no-attributes %_Nul3%
if not exist "%SystemRoot%\temp\Package_for_RollupFix*.mum" set branch=WinBuild
)
set _legacy=
set _useold=0
if /i "%branch%"=="WinBuild" set _useold=1
if /i "%branch%"=="GitEnlistment" set _useold=1
if /i "%uupdate%"=="winpbld" set _useold=1
if /i "%uupdate%"=="160101" set _useold=1
if %_useold% equ 1 (
wimlib-imagex.exe extract "%ISOdir%\Sources\%WimFile%" 1 Windows\System32\config\SOFTWARE --dest-dir=.\bin\temp --no-acls --no-attributes %_Null%
for /f "tokens=3 delims==:" %%# in ('"offlinereg.exe .\bin\temp\SOFTWARE "Microsoft\Windows NT\CurrentVersion" getvalue BuildLabEx" %_Nul6%') do if not errorlevel 1 (for /f "tokens=1-5 delims=." %%i in ('echo %%~#') do set _legacy=%%i.%%j.%%m.%%l&set branch=%%l)
)
if defined _legacy (set _label=%_legacy%) else (set _label=%uupver%.%uupdate%.%branch%)
rmdir /s /q bin\temp\
set _label=%_label%_CLIENT
for %%# in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do (
set _label=!_label:%%#=%%#!
set branch=!branch:%%#=%%#!
set langid=!langid:%%#=%%#!
)
if /i %arch%==x86 set archl=X86
if /i %arch%==x64 set archl=X64
if /i %arch%==arm64 set archl=A64
set _ddv=DV5
if %_build% geq 22621 set _ddv=DV9
set "DVDLABEL=CCSA_%archl%FRE_%langid%_%_ddv%"
if defined _exLabel set _label=%_exLabel%
set "DVDISO=%_label%MULTI_%archl%FRE_%langid%"
if exist "%DVDISO%.ISO" set "DVDISO=%DVDISO%_%random%"
goto :AUTOMENU

:dPREPARE
for /f "tokens=3 delims=: " %%# in ('imagex /info ISOFOLDER\Sources\%WimFile% ^|findstr /i /b /c:"Image Count"') do set finalimages=%%#
if %finalimages% gtr 1 exit /b
set _VL=0
for /f "tokens=3 delims=<>" %%# in ('imagex /info ISOFOLDER\Sources\%WimFile% 1 ^| find /i "<EDITIONID>"') do set _edtn=%%#
if /i %_edtn%==Core set DVDLABEL=CCRA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%CORE_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==CoreSingleLanguage set DVDLABEL=CSLA_%archl%FREO_%langid%_DV5&set DVDISO=%_label%SINGLELANGUAGE_OEM_%archl%FRE_%langid%
if /i %_edtn%==Professional set DVDLABEL=CPRA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%PRO_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==ProfessionalN set DVDLABEL=CPRNA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%PRON_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==Enterprise set DVDLABEL=CENA_%archl%FREV_%langid%_DV5&set DVDISO=%_label%ENTERPRISE_VOL_%archl%FRE_%langid%&set _VL=1
if /i %_edtn%==EnterpriseN set DVDLABEL=CENNA_%archl%FREV_%langid%_DV5&set DVDISO=%_label%ENTERPRISEN_VOL_%archl%FRE_%langid%&set _VL=1
if /i %_edtn%==Education set DVDLABEL=CEDA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%EDUCATION_RET_%archl%FRE_%langid%&set _VL=1
if /i %_edtn%==EducationN set DVDLABEL=CEDNA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%EDUCATIONN_RET_%archl%FRE_%langid%&set _VL=1
if /i %_edtn%==ProfessionalWorkstation set DVDLABEL=CPRWA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%PROWORKSTATION_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==ProfessionalWorkstationN set DVDLABEL=CPRWNA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%PROWORKSTATIONN_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==ProfessionalEducation set DVDLABEL=CPREA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%PROEDUCATION_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==ProfessionalEducationN set DVDLABEL=CPRENA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%PROEDUCATIONN_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==ServerRdsh set DVDLABEL=CEV_%archl%FREV_%langid%_DV5&set DVDISO=%_label%MULTISESSION_VOL_%archl%FRE_%langid%&set _VL=1
if /i %_edtn%==CloudEdition set DVDLABEL=CWCA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%CLOUD_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==CloudEditionN set DVDLABEL=CWCNNA_%archl%FRE_%langid%_DV5&set DVDISO=%_label%CLOUDN_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==IoTEnterprise set DVDLABEL=IOTEN_%archl%FRE_%langid%_DV5&set DVDISO=%_label%IOTENTERPRISE_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==IoTEnterpriseS set DVDLABEL=IOTES_%archl%FRE_%langid%_DV5&set DVDISO=%_label%IOTENTERPRISES_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==IoTEnterpriseSK set DVDLABEL=IOTESK_%archl%FRE_%langid%_DV5&set DVDISO=%_label%IOTENTERPRISESK_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==IoTEnterpriseK set DVDLABEL=IOTENK_%archl%FRE_%langid%_DV5&set DVDISO=%_label%IOTENTERPRISEK_OEMRET_%archl%FRE_%langid%
if /i %_edtn%==EnterpriseS set DVDLABEL=CES_%archl%FREV_%langid%_DV5&set DVDISO=%_label%ENTERPRISES_VOL_%archl%FRE_%langid%&set _VL=1
if /i %_edtn%==EnterpriseSN set DVDLABEL=CESN_%archl%FREV_%langid%_DV5&set DVDISO=%_label%ENTERPRISESN_VOL_%archl%FRE_%langid%&set _VL=1
if %_VL% equ 0 exit /b
(
echo [EditionID]
echo %_edtn%
echo.
echo [Channel]
echo Volume
echo.
echo [VL]
echo 1
)>ISOFOLDER\Sources\EI.CFG
exit /b

:get_lcu_pkg
if not exist "%SystemRoot%\temp\" mkdir "%SystemRoot%\temp" %_Nul3%
wimlib-imagex.exe extract "%ISOdir%\sources\%WimFile%" 1 Windows\Servicing\Packages\Package_for_RollupFix*.mum --dest-dir=.\bin\temp --no-acls --no-attributes %_Nul3%
if not exist "bin\temp\Package_for_RollupFix*.mum" (
call set uupdate=%bkpdate%
set "isotime=!uupdate:~2,2!/!uupdate:~4,2!/20!uupdate:~0,2!,!uupdate:~7,2!:!uupdate:~9,2!:10"
exit /b
)
for /f %%# in ('dir /b /a:-d /od bin\temp\Package_for_RollupFix*.mum') do copy /y "bin\temp\%%#" %SystemRoot%\temp\update.mum %_Nul1%
call :datemum uupdate isotime
exit /b

:datemum
set "mumfile=%SystemRoot%\temp\update.mum"
set "chkfile=!mumfile:\=\\!"
if %_cwmi% equ 1 for /f "tokens=2 delims==" %%# in ('wmic datafile where "name='!chkfile!'" get LastModified /value') do set "mumdate=%%#"
if %_cwmi% equ 0 for /f %%# in ('%_psc% "([WMI]'CIM_DataFile.Name=''!chkfile!''').LastModified"') do set "mumdate=%%#"
del /f /q %SystemRoot%\temp\*.mum
set "%1=!mumdate:~2,2!!mumdate:~4,2!!mumdate:~6,2!-!mumdate:~8,4!"
set "%2=!mumdate:~4,2!/!mumdate:~6,2!/!mumdate:~0,4!,!mumdate:~8,2!:!mumdate:~10,2!:!mumdate:~12,2!"
exit /b

:setuphostprep
wimlib-imagex.exe extract "%ISOdir%\Sources\boot.wim" 2 sources\setuphost.exe --dest-dir=%SystemRoot%\temp --no-acls --no-attributes %_Null%
wimlib-imagex.exe extract "%ISOdir%\Sources\boot.wim" 2 sources\setupprep.exe --dest-dir=%SystemRoot%\temp --no-acls --no-attributes %_Null%
wimlib-imagex.exe extract "%ISOdir%\Sources\%WimFile%" 1 Windows\system32\UpdateAgent.dll --dest-dir=%SystemRoot%\temp --no-acls --no-attributes %_Null%
wimlib-imagex.exe extract "%ISOdir%\Sources\%WimFile%" 1 Windows\system32\Facilitator.dll --dest-dir=%SystemRoot%\temp --no-acls --no-attributes %_Null%
set _svr1=0&set _svr2=0&set _svr3=0&set _svr4=0
set "_fvr1=%SystemRoot%\temp\setuphost.exe"
set "_fvr2=%SystemRoot%\temp\setupprep.exe"
set "_fvr3=%SystemRoot%\temp\UpdateAgent.dll"
set "_fvr4=%SystemRoot%\temp\Facilitator.dll"
set "cfvr1=!_fvr1:\=\\!"
set "cfvr2=!_fvr2:\=\\!"
set "cfvr3=!_fvr3:\=\\!"
set "cfvr4=!_fvr4:\=\\!"
if %_cwmi% equ 1 (
if exist "!_fvr1!" for /f "tokens=5 delims==." %%a in ('wmic datafile where "name='!cfvr1!'" get Version /value ^| find "="') do set /a "_svr1=%%a"
if exist "!_fvr2!" for /f "tokens=5 delims==." %%a in ('wmic datafile where "name='!cfvr2!'" get Version /value ^| find "="') do set /a "_svr2=%%a"
if exist "!_fvr3!" for /f "tokens=5 delims==." %%a in ('wmic datafile where "name='!cfvr3!'" get Version /value ^| find "="') do set /a "_svr3=%%a"
if exist "!_fvr4!" for /f "tokens=5 delims==." %%a in ('wmic datafile where "name='!cfvr4!'" get Version /value ^| find "="') do set /a "_svr4=%%a"
)
if %_cwmi% equ 0 (
if exist "!_fvr1!" for /f "tokens=4 delims=." %%a in ('%_psc% "([WMI]'CIM_DataFile.Name=''!cfvr1!''').Version"') do set /a "_svr1=%%a"
if exist "!_fvr2!" for /f "tokens=4 delims=." %%a in ('%_psc% "([WMI]'CIM_DataFile.Name=''!cfvr2!''').Version"') do set /a "_svr2=%%a"
if exist "!_fvr3!" for /f "tokens=4 delims=." %%a in ('%_psc% "([WMI]'CIM_DataFile.Name=''!cfvr3!''').Version"') do set /a "_svr3=%%a"
if exist "!_fvr4!" for /f "tokens=4 delims=." %%a in ('%_psc% "([WMI]'CIM_DataFile.Name=''!cfvr4!''').Version"') do set /a "_svr4=%%a"
)
set "_chk=!_fvr1!"
if %chkmin% equ %_svr1% set "_chk=!_fvr1!"&goto :prephostsetup
if %chkmin% equ %_svr2% set "_chk=!_fvr2!"&goto :prephostsetup
if %chkmin% equ %_svr3% set "_chk=!_fvr3!"&goto :prephostsetup
if %chkmin% equ %_svr4% set "_chk=!_fvr4!"&goto :prephostsetup
if %_svr2% gtr %_svr1% (
if %_svr2% gtr %_svr3% if %_svr2% gtr %_svr4% set "_chk=!_fvr2!"
if %_svr3% gtr %_svr2% if %_svr3% gtr %_svr4% set "_chk=!_fvr3!"
if %_svr4% gtr %_svr2% if %_svr4% gtr %_svr3% set "_chk=!_fvr4!"
)
if %_svr3% gtr %_svr1% (
if %_svr2% gtr %_svr3% if %_svr2% gtr %_svr4% set "_chk=!_fvr2!"
if %_svr3% gtr %_svr2% if %_svr3% gtr %_svr4% set "_chk=!_fvr3!"
if %_svr4% gtr %_svr2% if %_svr4% gtr %_svr3% set "_chk=!_fvr4!"
)
if %_svr4% gtr %_svr1% (
if %_svr2% gtr %_svr3% if %_svr2% gtr %_svr4% set "_chk=!_fvr2!"
if %_svr3% gtr %_svr2% if %_svr3% gtr %_svr4% set "_chk=!_fvr3!"
if %_svr4% gtr %_svr2% if %_svr4% gtr %_svr3% set "_chk=!_fvr4!"
)

:prephostsetup
7z.exe l "%_chk%" >.\bin\version.txt 2>&1
del /f /q "!_fvr1!" "!_fvr2!" "!_fvr3!" "!_fvr4!" %_Nul3%
exit /b

:checkadk
set _dism1=dism.exe
set _dism2=dism.exe /ScratchDir
set _ADK=0
set regKeyPathFound=1
set wowRegKeyPathFound=1
reg.exe query "HKLM\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots" /v KitsRoot10 %_Nul3% || set wowRegKeyPathFound=0
reg.exe query "HKLM\Software\Microsoft\Windows Kits\Installed Roots" /v KitsRoot10 %_Nul3% || set regKeyPathFound=0
if %wowRegKeyPathFound% equ 0 (
  if %regKeyPathFound% equ 0 (
    goto :eof
  ) else (
    set regKeyPath=HKLM\Software\Microsoft\Windows Kits\Installed Roots
  )
) else (
    set regKeyPath=HKLM\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots
)
for /f "skip=2 tokens=2*" %%i in ('reg.exe query "%regKeyPath%" /v KitsRoot10') do set "KitsRoot=%%j"
set "DandIRoot=%KitsRoot%Assessment and Deployment Kit\Deployment Tools"
if exist "%DandIRoot%\%xOS%\DISM\dism.exe" (
set _ADK=1
set "Path=%xDS%;%DandIRoot%\%xOS%\DISM;%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\"
)
goto :eof

:pr_color
set _NCS=1
if %winbuild% LSS 10586 set _NCS=0
if %winbuild% GEQ 10586 reg.exe query HKCU\Console /v ForceV2 2>nul | find /i "0x0" %_Null% && (set _NCS=0)

if %_NCS% EQU 1 (
for /F %%a in ('echo prompt $E ^| cmd.exe') do set "_esc=%%a"
set     "Red="41;97m" "pad""
set    "Gray="100;97m" "pad""
set   "Green="42;97m" "pad""
set    "Blue="44;97m" "pad""
set  "_White="40;37m" "pad""
set  "_Green="40;92m" "pad""
set "_Yellow="40;93m" "pad""
) else (
set     "Red="Red" "white""
set    "Gray="DarkGray" "white""
set   "Green="DarkGreen" "white""
set    "Blue="Blue" "white""
set  "_White="Black" "Gray""
set  "_Green="Black" "Green""
set "_Yellow="Black" "Yellow""
)

set "_err=echo: &call :dk_color1 %Red% "==== 出错 ====" &echo:" 
exit /b

:dk_color1
if /i "%_Exit%"=="rem." (
echo %~3
exit /b
)
if not "%4"=="" if "%4"=="4" echo:
if %_NCS% EQU 1 (
echo %_esc%[%~1%~3%_esc%[0m
) else if %_pwsh% EQU 1 (
%_psc% write-host -back '%1' -fore '%2' '%3'
) else (
echo %~3
)
if not "%5"=="" echo:
exit /b

:dk_color2
if /i "%_Exit%"=="rem." (
echo %~3 %~6
exit /b
)
if not "%7"=="" if "%7"=="7" echo:
if %_NCS% EQU 1 (
echo %_esc%[%~1%~3%_esc%[%~4%~6%_esc%[0m
) else if %_pwsh% EQU 1 (
%_psc% write-host -back '%1' -fore '%2' '%3' -NoNewline; write-host -back '%4' -fore '%5' '%6'
) else (
echo %~3 %~6
)
if not "%8"=="" echo:
exit /b

:checkQE
if not defined qerel reg.exe query HKCU\Console /v QuickEdit 2>nul | find /i "0x0" >nul || (
call :dk_color1 %Red% "### 警告 ###" 
echo.
echo 命令行“快速编辑模式”处于启用状态。 
echo 请不要在当前窗口内单击鼠标左键，否则 
echo 执行中的命令将会被暂停，直到按下键盘某个键为止。 
echo.
set _preMount=4
)
exit /b

:E_Admin
%_err%
echo 此脚本需要以管理员权限运行。 
echo 如需继续，请在脚本上右键单击并选择“以管理员权限运行” 
goto :E_Exit

:E_PWS
%_err%
echo 未检测到 Windows PowerShell 或未正确响应。 
echo 此脚本需要它才能工作。 
goto :E_Exit

:E_Exit
if %_Debug% neq 0 exit /b
echo.
echo 按任意键退出。 
pause >nul
exit /b

:E_Bin
%_err%
echo 所需的文件 %_bin% 丢失。 
echo.
goto :QUIT

:E_MSG
:: @color 47
if %_build% geq 19041 if %winbuild% lss 17133 if exist "%SysPath%\ext-ms-win-security-slc-l1-1-0.dll" (
del /f /q %SysPath%\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
if /i not %xOS%==x86 del /f /q %SystemRoot%\SysWOW64\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
)
if exist "ISOFOLDER\Sources\*.exe" ren ISOFOLDER %DVDISO% %_Nul3%
%_err%
echo %MESSAGE%
echo.
(echo.&echo %MESSAGE%)>>"!logerr!"
goto :QUIT

:E_None
:: @color 0F
if %_exDism% equ 1 exit /b
if %UseDism% neq 1 if exist ISOFOLDER\Sources\temp.wim del /f /q ISOFOLDER\Sources\temp.wim
call :dPREPARE
ren ISOFOLDER %DVDISO%
if %modded% equ 0 (
echo.
echo 所有选定的版本都已存在于源文件中 
)
call :dk_color1 %Gray% "无执行操作。" 4 5 
goto :QUIT

:E_ISO
:: @color 17
ren ISOFOLDER %DVDISO%
call :dk_color1 %Red% "在写入 ISO 镜像文件时出错。" 4 5 
(echo.&echo 在写入 ISO 镜像文件时出错。)>>"!logerr!" 
goto :QUIT

:QUIT
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
if exist bin\temp\ rmdir /s /q bin\temp\
if exist bin\infoall.txt del /f /q bin\infoall.txt
popd
if %_Debug% neq 0 exit /b
if defined qmsg call :dk_color1 %Green% "%qmsg%" 4
call :dk_color1 %_Yellow% "按下 0 或 q 以退出。" 
choice /c 0Q /n
if errorlevel 1 (exit /b) else (rem.)

----- wsf 脚本开始 ---> 
<package>
   <job id="ELAV">
      <script language="VBScript">
         Set strArg=WScript.Arguments.Named
         Set strRdlproc = CreateObject("WScript.Shell").Exec("rundll32 kernel32,Sleep")
         With GetObject("winmgmts:\\.\root\CIMV2:Win32_Process.Handle='" & strRdlproc.ProcessId & "'")
            With GetObject("winmgmts:\\.\root\CIMV2:Win32_Process.Handle='" & .ParentProcessId & "'")
               If InStr (.CommandLine, WScript.ScriptName) <> 0 Then
                  strLine = Mid(.CommandLine, InStr(.CommandLine , "/File:") + Len(strArg("File")) + 8)
               End If
            End With
            .Terminate
         End With
         CreateObject("Shell.Application").ShellExecute "cmd.exe", "/c " & chr(34) & chr(34) & strArg("File") & chr(34) & strLine & chr(34), "", "runas", 1
      </script>
   </job>
</package>

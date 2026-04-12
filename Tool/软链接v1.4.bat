@echo off
chcp 936 >nul
title 软链接v1.4 更新：添加断开链接功能 QQ：1377820366

::说明内容，可以删除
echo 说明：
echo 什么是文件链接？
echo 简单来说就是把源目录变成快捷方式，但是通过链接目录跳转过去的路径是以链接目录的路径为准
echo 而不是快捷方式那种跳转路径，而是把目标路径的任容映射过来，效果和原目录一样
echo 文件实际使用的是目标目录的容量，而且文件也只有一份，不是复制
echo 只是通过源目录可以直接使用和管理目标目录的文件，软件会把目标目录的文件当成源目录的文件
echo ============================
echo 作者：树梢上有只鸟（Treetop）
echo 嫌废话多可以右键文件选择编辑把 echo 开头的说明内容删除
echo 删除说明不会有任何功能上的影响
echo 这只是一个简单的bat工具，没有什么神奇的功能
echo 代码也非常简单，免费使用
echo 如果无法使用那我也没办法
echo 本工具下载链接：https://www.lanzout.com/b01kghj7g 密码：dyv1
echo ============================
echo 回车表示已看完并同意确认以上内容
pause >nul
cls

:MainMenu
echo 请选择操作：
echo 1. 创建软链接
echo 2. 断开软链接
echo 3. 退出
echo.
set /p choice="请选择 (1/2/3): "

if "%choice%"=="1" goto CreateLink
if "%choice%"=="2" goto BreakLink
if "%choice%"=="3" exit
echo 无效选择，请重新输入
goto MainMenu

:CreateLink
cls
echo 提示：源目录 链接到 目标目录 ，文件实际储存在 目标目录 ，不要弄反了！！
echo 如果目录或文件夹的名字中包含空格需要在前后加上英文的双引号 ""
echo 如果权限不足请使用管理员运行此脚本！
echo ============================
if "%1"=="" (
    echo 请粘贴 源目录 或拖动 源文件夹 到这里，然后按回车确认，如已拖入文件夹直接回车跳过即可
    set /p F1=">>"
    )
if "%2"=="" (
    echo 请粘贴 目标目录 或拖动 目标文件夹 到这里，然后按回车确认，如已拖入文件夹直接回车跳过即可
    set /p F2=">>"
    )
if "%1"=="" set "F1=%F1%"
if "%2"=="" set "F2=%F2%"
if "%1" neq "" set "F1=%1"
if "%2" neq "" set "F2=%2"

cls
echo 开始链接
echo 源始目录：%F1%
echo 目标目录：%F2%
echo ============================
echo 注意：
echo 会自动转移 源始目录 的文件到 目标目录 ，请别担心
echo 如果开始链接后什么都不显示可能是需要转移的文件过大导致缓慢或文件占有等
echo 如遇到文件无法转移的情况可以直接关闭窗口手动转移试试
echo 记得先取消所有其他调用这两个目录的行为和软件，否则可能会因为占用而失败！
echo 因为占有而失败不保证文件是否会损坏
echo 请检查上方显示目录是否正确
echo ============================
echo 回车以开始链接...
pause >nul

cls
echo 文件迁移中，请耐心等待...
xcopy "%F1%" "%F2%\" /q /e /r /S /Y
echo ============================
echo 文件迁移完成！
rd /s/q "%F1%"
echo 移除原文件夹完成！
echo ============================
echo 创建链接中，请耐心等待...
mklink /j "%F1%" "%F2%"
echo ============================
echo 文件夹链接结束！
echo 如无报错等可以回车或关闭窗口。
pause >nul
goto MainMenu

:BreakLink
cls
echo 断开软链接功能
echo ============================
echo 此功能将断开软链接，并将链接目录和目标目录都保留为独立的文件夹
echo 文件将会被复制两份，分别保存在原来的链接位置和目标位置
echo ============================
set /p LinkPath="请输入或拖动软链接目录路径: "

echo.
echo 正在验证链接...

:: 移除路径可能的引号
set "LinkPath=%LinkPath:"=%"
set "TargetPath="

:: 方法1: 使用 dir 命令查找链接目标
for /f "tokens=2 delims=[]" %%A in ('dir "%LinkPath%" ^| find "<SYMLINK>"') do (
    set "TargetPath=%%A"
)

:: 方法2: 如果方法1失败，使用 fsutil
if not defined TargetPath (
    for /f "tokens=2*" %%A in ('fsutil reparsepoint query "%LinkPath%" 2^>nul ^| find "Symbolic Link"') do (
        set "TargetPath=%%B"
    )
)

if not defined TargetPath (
    echo 错误：无法确定软链接的目标路径！
    echo 请确认这是一个有效的软链接目录
    pause >nul
    goto MainMenu
)

echo 检测到软链接目标: %TargetPath%
echo.

:: 创建临时目录来中转文件
set "TempDir=%Temp%\LinkBreak_%RANDOM%"
mkdir "%TempDir%" 2>nul

echo 步骤1: 复制目标目录文件到临时位置...
xcopy "%TargetPath%" "%TempDir%\" /q /e /h /r /S /Y /I
if errorlevel 1 (
    echo 错误：复制文件失败！
    rd /q "%TempDir%" 2>nul
    pause >nul
    goto MainMenu
)

echo 文件复制到临时位置完成！

echo.
echo 步骤2: 删除软链接...
rd "%LinkPath%" 2>nul
if exist "%LinkPath%" (
    echo 警告：无法删除软链接，可能被占用
    echo 请手动删除: %LinkPath%
    echo 然后按任意键继续...
    pause >nul
)

echo.
echo 步骤3: 将文件复制回原链接位置...
xcopy "%TempDir%" "%LinkPath%\" /q /e /h /r /S /Y /I

echo.
echo 步骤4: 清理临时文件...
rd /s /q "%TempDir%" 2>nul

echo.
echo 断开链接完成！
echo 现在有两个独立的文件夹：
echo 原链接位置: %LinkPath%
echo 原目标位置: %TargetPath%
echo 两个目录都包含完整的文件副本
echo.
pause >nul
goto MainMenu
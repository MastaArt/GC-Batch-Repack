:: Extracter
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off
cls

set input=%1
set arg1=
set arg2=

for /f "tokens=1,2 delims=;" %%I in (%input%) do (
	set arg1=%%I
	set arg2=%%J
)

7za.exe a "%arg1%" "%arg2%*.*" -r
rmdir "%arg2%" /s /q

exit 0
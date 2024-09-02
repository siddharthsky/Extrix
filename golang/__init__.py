go mod tidy   

$env:CC="C:\android-ndk-r27\toolchains\llvm\prebuilt\windows-x86_64\bin\armv7a-linux-androideabi21-clang"
$env:CGO_ENABLED="1"  
$env:GOARCH="arm"
$env:GOOS="android"  

go build -o majorbin_arm .  

# Серия скриншотов: каждый элемент — строка аргументов, первым идёт имя файла.
param([string[]]$Specs)
$s = "C:\Users\Admin\AppData\Local\Temp\claude\C--Users-Admin-Desktop-----\0f8e59b4-3a9f-4077-b539-f1c30f18ff7e\scratchpad"
foreach ($spec in $Specs) {
    $parts = $spec -split "\s+"
    $name = $parts[0]
    $ga = @($parts[1..($parts.Count-1)] | ForEach-Object { "--" + $_ }) + "--out=$s\$name.png"
    $r = & "$PSScriptRoot\check.ps1" -Window -GameArgs $ga
    "$name : $($r -join ' | ')"
}

# Get the current directory path
$currentDirectory = (Get-Location).Path

# Find all .msi files in the current directory
$msiFiles = Get-ChildItem -Path $currentDirectory -Filter *.msi

# Loop through each MSI file and perform administrative install
foreach ($msiFile in $msiFiles) {
    # Get the MSI file name without extension
    $folderName = [System.IO.Path]::GetFileNameWithoutExtension($msiFile.FullName)

    # Create a new directory with the folder name
    $destinationDirectory = New-Item -Path (Join-Path -Path $currentDirectory -ChildPath $folderName) -ItemType Directory

    # Perform MSI administrative install to extract the contents
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/a `"$($msiFile.FullName)`" /qn TARGETDIR=`"$($destinationDirectory.FullName)`"" -Wait -NoNewWindow
}

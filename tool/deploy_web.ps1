# Publishes the web build to GitHub Pages.
#
# ASCII only, deliberately. Windows PowerShell 5.1 reads a .ps1 with no BOM as
# ANSI, so a single em dash in a comment turns the file into a parse error --
# which is how the first version of this script failed.
#
# The site is a PROJECT page -- github.io/<user>/hajjoperations/ -- not a user
# page, so it is served from a subdirectory. That single fact is what makes a
# plain `flutter build web` unusable here: the default `<base href="/">` sends
# every asset request to the domain root, and the result is a white screen with
# a console full of 404s and nothing to say why. Hence --base-href below, and
# hence this script rather than a line in a README that somebody will forget.
#
# Deep links survive because the app leaves Flutter's default HASH routing
# alone: everything after `#` never reaches GitHub's server, so there is no
# rewrite to configure and no 404.html trick to maintain. If anybody ever calls
# `usePathUrlStrategy()`, this stops being true and reloading on any route but
# the first will 404 -- copy index.html to 404.html then, and know why.
#
#   powershell -ExecutionPolicy Bypass -File tool/deploy_web.ps1
#
# The branch is replaced whole every time, deliberately. It holds build output,
# not history; keeping old bundles would only grow the clone for nobody.

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

$origin = (git remote get-url origin).Trim()
$source = (git rev-parse --short HEAD).Trim()
$branch = (git rev-parse --abbrev-ref HEAD).Trim()

# The subdirectory the site is served from, taken from the remote rather than
# typed, so renaming the repository does not silently break the asset paths.
$project = [IO.Path]::GetFileNameWithoutExtension(($origin -split '/')[-1])

Write-Host "building $project @ $source ($branch)" -ForegroundColor Cyan
flutter build web --release --base-href "/$project/"
if ($LASTEXITCODE -ne 0) { throw 'the build failed - nothing was published' }

$staging = Join-Path ([IO.Path]::GetTempPath()) "$project-pages"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
Copy-Item (Join-Path $repo 'build\web') $staging -Recurse

# Without this, GitHub runs the output through Jekyll, which silently drops
# anything beginning with an underscore. Flutter emits none today; it costs one
# empty file to not depend on that staying true.
New-Item -ItemType File -Path (Join-Path $staging '.nojekyll') | Out-Null

Push-Location $staging
try {
    git init -q -b gh-pages
    git remote add origin $origin
    git add -A
    git -c user.name='deploy' -c user.email='deploy@local' commit -q -m "build of $source from $branch"
    git push -q -f origin gh-pages
} finally {
    Pop-Location
}

$owner = ($origin -replace '.*github\.com[:/]', '') -split '/' | Select-Object -First 1
Write-Host "published -> https://$owner.github.io/$project/" -ForegroundColor Green
Write-Host 'Settings / Pages / Source: "Deploy from a branch" -> gh-pages / (root)'

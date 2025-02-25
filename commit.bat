@echo off
REM Ensure script stops on errors
setlocal enabledelayedexpansion

REM Check if both arguments are provided
IF "%~1"=="" (
    echo ERROR: Please provide a version tag and commit message.
    echo Usage: push_release.bat v1.0.1 "Your commit message"
    exit /b 1
)

IF "%~2"=="" (
    echo ERROR: Please provide a commit message.
    echo Usage: push_release.bat v1.0.1 "Your commit message"
    exit /b 1
)

SET TAG=%1
SHIFT
SET COMMIT_MESSAGE=%*

echo 1 Adding and committing changes...
git add .
git commit -m "%COMMIT_MESSAGE%"

echo 2 Creating new tag: %TAG%
git tag %TAG%

echo 3 Pushing commits and tag to remote...
git push origin main --tags

echo ✅ Release %TAG% pushed successfully with commit message: "%COMMIT_MESSAGE%"
exit /b 0

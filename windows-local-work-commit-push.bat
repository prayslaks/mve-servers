cd ./mve-login-server
git add .
git commit --amend --no-edit
git push -f origin main
cd ..
cd ./mve-resource-server
git add .
git commit --amend --no-edit
git push -f origin main
cd ..
git add .
git commit --amend --no-edit
git push -f origin main
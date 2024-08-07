sudo apt-get update
sudo apt-get install -y git build-essential git-flow

# configure git for proxy

# git config --global http.proxy http://zrh1-2.sme.zscloud.net:10268

email="$(git config --global user.email || true)"
name="$(git config --global user.name || true)"

if [ -z $"$email" ]; then
    read -p "please enter your email address used as git author:" email
fi

if [ -z $"$name" ]; then
    read -p "please enter your full name used as git author:" name
fi

git config --global user.email "$email"
git config --global user.name "$name"

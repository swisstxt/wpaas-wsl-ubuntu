sudo apt-get update
sudo apt-get install -y git build-essential

# configure git for proxy

git config --global http.proxy http://gateway.zscloud.net:10268

email=$(git config --global user.email)
name=$(git config --global user.name)

if [ -z $"$email" ]; then
    read -p "please enter your email address used as git author:" email
fi

if [ -z $"$name" ]; then
    read -p "please enter your full name used as git author:" name
fi

git config --global user.email "$email"
git config --global user.name "$name"
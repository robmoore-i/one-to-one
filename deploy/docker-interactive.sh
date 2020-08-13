if [[ $(docker image list | grep "one-to-one" | wc -l | tr -d ' ') != "1" ]]; then
  echo "Looks like you haven't yet built the docker image. Try running ./deploy/build-container.sh first."
  exit 1
fi

docker run -it one-to-one:latest bash
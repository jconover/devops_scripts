# Build & Run

# Fedora 42

## build (single-arch)
docker build -f Dockerfile.fedora42 -t yourname/devops-tools:fedora42 .

## or multi-arch with Buildx
docker buildx build -f Dockerfile.fedora42 --platform linux/amd64,linux/arm64 -t yourname/devops-tools:fedora42 --push .

## run (mount common creds)
docker run -it --rm \
  -v $HOME/.kube:/home/devops/.kube \
  -v $HOME/.aws:/home/devops/.aws \
  -v $HOME/.config/gcloud:/home/devops/.config/gcloud \
  -v $HOME/.azure:/home/devops/.azure \
  yourname/devops-tools:fedora42

----------------------------------------------------------------------------------------------------
# Ubuntu 24.04 LTS

# single-arch
docker build -f Dockerfile.ubuntu24.04 -t yourname/devops-tools:ubuntu24.04 .

# or multi-arch (requires Buildx)
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.ubuntu24.04 -t yourname/devops-tools:ubuntu24.04 --push .

# Run with your local creds mounted (handy)
docker run -it --rm \
  -v $HOME/.kube:/home/devops/.kube \
  -v $HOME/.aws:/home/devops/.aws \
  -v $HOME/.config/gcloud:/home/devops/.config/gcloud \
  -v $HOME/.azure:/home/devops/.azure \
  yourname/devops-tools:ubuntu24.04

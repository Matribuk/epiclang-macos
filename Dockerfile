# Image Epitech pour macOS : epiclang + le plug-in de coding style banana.
# La PPA Epitech ne publie qu'en amd64, l'image est donc linux/amd64.
FROM --platform=linux/amd64 ubuntu:26.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates software-properties-common \
 && add-apt-repository -y ppa:epitech/ppa \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      epiclang banana-coding-style-checker build-essential \
 && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["epiclang"]

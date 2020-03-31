FROM google/cloud-sdk:266.0.0-alpine

RUN apk add --no-cache jq && \
    curl https://storage.googleapis.com/kubernetes-release/release/v1.13.12/bin/linux/amd64/kubectl > /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

COPY . /app
WORKDIR /app

ENTRYPOINT ["/app/gatekeeper.bash"]

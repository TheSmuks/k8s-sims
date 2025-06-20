FROM docker:dind AS builder

RUN apk update && apk add --no-cache \
    build-base \
    ca-certificates \
    curl \
    go \
    python3 \
    py3-pip \
    git \
    bash \
    openssl \
    libffi-dev \
    musl-dev

ENV PATH="/root/.cargo/bin:/root/go/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
RUN rustup default stable && rustup update

RUN cargo install skctl && \
    go install sigs.k8s.io/kind@v0.29.0 && \
    go install sigs.k8s.io/kwok/cmd/kwok@v0.7.0 && \
    go install sigs.k8s.io/kwok/cmd/kwokctl@v0.7.0

RUN curl -sSL https://dl.k8s.io/release/v1.33.2/bin/linux/amd64/kubectl \
    -o /kubectl && chmod +x /kubectl

COPY requirements.txt /requirements.txt
RUN pip install --target=/pylib -r /requirements.txt

FROM docker:dind

RUN apk update && apk add --no-cache \
    ca-certificates \
    iptables \
    python3 \
    git \
    iproute2 \
    bash \
    cgroup-tools \
    go

COPY --from=builder /root/go/bin /root/go/bin
COPY --from=builder /kubectl /root/go/bin/kubectl
COPY --from=builder /root/.cargo /root/.cargo
COPY --from=builder /pylib /pylib

ENV PATH="/root/go/bin:/root/.cargo/bin:${PATH}"
ENV PYTHONPATH=/pylib

WORKDIR /
COPY data /data
COPY modules /modules
RUN chmod +x /modules/opensim/cmd
COPY experiment-base.sh /experiment-base.sh
COPY run-all-experiments.sh /run-all-experiments.sh
COPY requirements.txt /requirements.txt

RUN mkdir -p /utils /results
COPY utils/base /utils/base
COPY utils/kube-gen.py /utils/kube-gen.py
COPY utils/simkube-tracer.sh /utils/simkube-tracer.sh
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\bsudo\b//g' /modules/opensim/module.sh
RUN echo 'rc_cgroup_mode="unified"' | tee -a /etc/rc.conf

ENTRYPOINT ["/entrypoint.sh"]

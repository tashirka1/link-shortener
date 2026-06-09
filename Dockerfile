FROM alpine:3.23 AS builder
RUN apk add --no-cache curl tar xz
ENV ZIG_VERSION=0.16.0
ENV ZIG_FOLDER=zig-x86_64-linux-${ZIG_VERSION}
ENV ZIG_TARBALL=${ZIG_FOLDER}.tar.xz
RUN curl -LO https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TARBALL} \
    && tar -xf ${ZIG_TARBALL} -C /opt/ \
    && rm ${ZIG_TARBALL} \
    && ln -s /opt/${ZIG_FOLDER}/zig /usr/local/bin/zig
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/app/.zig-cache \
    zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-linux-musl

FROM alpine:3.23 AS run
COPY --from=builder /app/zig-out/bin/link_shortener /app/link_shortener
RUN adduser --disabled-password --gecos "" noroot && \
    mkdir -p /app/db && \
    chown -R noroot:noroot /app
WORKDIR /app
USER noroot:noroot
EXPOSE 8000
CMD ["/app/link_shortener"]

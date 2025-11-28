#
# Stage 1
#
FROM library/golang:1 as builder

# [修改 1] 适配新版 Go (1.17+):
# 'go get' 安装可执行文件已被弃用/移除，必须改为 'go install ...@latest'
# 同时 godep 项目已归档，需要通过 master 分支或 latest 安装
RUN go install github.com/tools/godep@latest

# Recompile the standard library without CGO
# 注意：在新版 Go 中这一步其实通常是不必要的，但在旧项目中保留也没坏处
RUN CGO_ENABLED=0 go install -a std

ENV APP_DIR $GOPATH/src/github.com/chartmuseum/ui
RUN mkdir -p $APP_DIR
ADD . $APP_DIR

# Compile the binary and statically link
RUN cd $APP_DIR && \
    # [修改 2] 明确 GOPATH 路径
    # 因为 go install 把 godep 放到了 $GOPATH/bin，需要确保它在 PATH 中
    export PATH=$PATH:$GOPATH/bin && \
    # 强制开启 GO111MODULE=off 以支持旧的 godep 模式 (因为 golang:1 默认现在是 on)
    GO111MODULE=off CGO_ENABLED=0 godep go build -ldflags '-w -s' -o /chartmuseum-ui && \
    cp -r views/ /views && \
    cp -r static/ /static

#
# Stage 2
#
FROM alpine:3.8
# [说明] alpine:3.8 比较老，但在 multi-arch 支持上没有问题
RUN apk add --no-cache curl cifs-utils ca-certificates \
    && adduser -D -u 1000 chartmuseum
COPY --from=builder /chartmuseum-ui /chartmuseum-ui
COPY --from=builder /views /views
COPY --from=builder /static /static
USER 1000
ENTRYPOINT ["/chartmuseum-ui"]

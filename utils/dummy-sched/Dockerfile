FROM golang:1.24.0 AS builder
LABEL authors="TheSmuks"

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o scheduler main.go

FROM alpine:latest

WORKDIR /
COPY --from=builder /app/scheduler .

ENTRYPOINT ["/scheduler"]

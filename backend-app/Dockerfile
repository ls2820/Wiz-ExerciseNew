# Build Stage
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/main .
COPY wizexercise.txt /app/wizexercise.txt
COPY assets/ ./assets/
COPY index.html .
EXPOSE 8080
# The CMD will run the binary
CMD ["./main"]
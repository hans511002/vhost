FROM alpine:latest

RUN apk --update add --no-cache bind

EXPOSE 53

CMD ["named", "-c", "/etc/bind/named.conf", "-g", "-u", "named"]

FROM alpine:3.18

RUN apk update && apk add --no-cache redis

COPY tools/script.sh /tmp/script.sh

RUN chmod u+x /tmp/script.sh

ENTRYPOINT ["/tmp/script.sh"]
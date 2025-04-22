FROM alpine:3.21

RUN apk update && apk add jq curl

WORKDIR /certificate

COPY download-cert.sh .

RUN chmod +x download-cert.sh

CMD ["/certificate/download-cert.sh"]
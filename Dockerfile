FROM postgres:15-alpine

RUN apk add --no-cache bash

WORKDIR /app

COPY maintenance.sh /app/maintenance.sh

RUN chmod +x /app/maintenance.sh

CMD ["./maintenance.sh"]

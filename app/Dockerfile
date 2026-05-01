FROM python:3.12-alpine

RUN apk add --no-cache ca-certificates iputils && \
    addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8080

USER app

ENTRYPOINT ["python3", "main.py"]

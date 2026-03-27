FROM python:3.11-slim

RUN apt-get update && apt-get install -y dvgrab procps && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN pip install flask

COPY app.py .
COPY templates/ templates/
COPY static/ static/

ENTRYPOINT ["python3", "app.py"]

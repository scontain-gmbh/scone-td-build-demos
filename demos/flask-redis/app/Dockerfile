FROM python:3.11-alpine

WORKDIR /app

COPY app.py .
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 4996

CMD ["/usr/local/bin/python", "app.py"]

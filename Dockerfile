FROM python:3.12-slim

# Prevent Python from writing .pyc and buffering logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ .

EXPOSE 5000

CMD ["python", "main.py"]

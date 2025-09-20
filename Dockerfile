# Simple Dockerfile for hello.py
# Using a small, secure base image
FROM python:3.13-slim

# Avoids writing .pyc files and forces stdout/stderr to be unbuffered
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Copy only the script (no dependencies needed)
COPY hello.py /app/hello.py

# Run the script
CMD ["python", "hello.py"]

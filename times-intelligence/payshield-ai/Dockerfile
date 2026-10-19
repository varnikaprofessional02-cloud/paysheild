# PayShield AI service. Same image runs the API (default) and the Service Bus worker:
#   docker run ... times-payshield-ai                                 -> API on :8080
#   docker run ... times-payshield-ai python -m app.messaging.worker  -> worker
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 WEB_CONCURRENCY=2
WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin payshield && chown -R 10001 /srv
USER 10001

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/api/v1/health/live',timeout=4).status==200 else 1)"

CMD ["sh", "-c", "uvicorn app.main:create_app --factory --host 0.0.0.0 --port 8080 --proxy-headers --workers ${WEB_CONCURRENCY}"]

# Flowplan on Railway: the official upstream image, pinned by version and digest,
# plus a small start script (first-boot admin, memory caps for small plans).
FROM ghcr.io/yannicschuller/flowplan:0.11.4@sha256:2c46d5a7442928039ad5af52f47976273cc7081d1a33a5825ee7bad7bf882565

COPY --chmod=755 railway-start.sh /app/railway-start.sh
COPY --chmod=644 railway-bootstrap.mjs /app/railway-bootstrap.mjs

# Same defaults as the upstream image; Railway routes the public domain to PORT.
ENV FLOWPLAN_DATA_DIR=/app/data PORT=3000

CMD ["/app/railway-start.sh"]

FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src

RUN npm run build

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

# Copy TLS certificates (optional, used when HTTPS_ENABLED=true)
COPY certs ./certs
RUN chmod 644 certs/*.pem 2>/dev/null || true

USER node

EXPOSE 3000

CMD ["node", "dist/index.js"]

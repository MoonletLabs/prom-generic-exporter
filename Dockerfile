FROM node:22-alpine as builder
ADD build /app
RUN npm install -g pnpm
WORKDIR /app
RUN pnpm install --prod

FROM node:22-alpine
# ADD build /app
COPY --from=builder /app /app
WORKDIR /app

CMD ["node", "/app/index.js", "/config/config.yml"]
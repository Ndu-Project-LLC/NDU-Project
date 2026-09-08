FROM node:20-alpine

WORKDIR /app
COPY auth-gate.js /app/auth-gate.js

ENV PORT=8080
EXPOSE 8080

CMD ["node", "auth-gate.js"]
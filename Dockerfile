# Container image for the namegen Node.js app (source is in this repo root, per the brief).
# The app listens on 8080 and reads MONGODB_URL to reach MongoDB.
FROM node:20-alpine

WORKDIR /usr/src/app

# Install deps first for better layer caching (package-lock.json is present -> npm ci, reproducible)
COPY package*.json ./
RUN npm ci --omit=dev

# App source
COPY . .

# Run as the built-in non-root 'node' user (least privilege)
RUN chown -R node:node /usr/src/app
USER node

EXPOSE 8080
CMD ["node", "server.js"]

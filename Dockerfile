# Container image for the namegen Node.js app (source is in this repo root, per the brief).
# The app listens on 8080 and reads MONGODB_URL to reach MongoDB.
FROM node:18-alpine
WORKDIR /usr/src/app

# Install deps first for better layer caching (package-lock.json is present -> npm ci)
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev

# App source
COPY . .

EXPOSE 8080
CMD ["node", "server.js"]

# Use official Node.js image
FROM node:18-alpine

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source files
COPY . .

# Environment variables (can be overridden in docker-compose)
ENV NODE_ENV=production
ENV DATA_DIR=/app/data

# Command to run the data processing
CMD ["npm", "run", "process-data"]
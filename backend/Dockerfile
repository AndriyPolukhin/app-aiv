FROM node:18-alpine

WORKDIR /app

# Cpy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

# Run the data processing script
CMD ["node", "server.js"]
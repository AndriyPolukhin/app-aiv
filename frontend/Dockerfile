FROM node:18-alpine

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

# Environment variables
ENV PORT=3000

# Expose port
EXPOSE 3000

# Start the development server
CMD ["npm", "start"]
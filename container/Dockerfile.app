# Use a specific version of node for consistency
FROM node:18-alpine AS base

# Install npm globally
RUN npm install -g npm@10.2.4

# Builder stage
FROM base AS builder

# Install necessary packages
RUN apk add --no-cache libc6-compat && apk update

# Set working directory
WORKDIR /app

# Install turbo globally
RUN npm install -g turbo@1.12.3

# Copy necessary files
COPY package*.json turbo.json ./
COPY ./apps/app ./apps/app

# Set up environment variables
ARG NPM_AUTH_TOKEN
ENV NPM_AUTH_TOKEN=$NPM_AUTH_TOKEN

# Configure npm
RUN echo "engine-strict=true" >> .npmrc && \
    echo "save-prefix=\"\"" >> .npmrc && \
    echo "//npm.pkg.github.com/:_authToken=$NPM_AUTH_TOKEN" >> .npmrc && \
    echo "@maheshyadav7702:registry=https://npm.pkg.github.com" >> .npmrc && \
    echo "registry=https://registry.npmjs.org" >> .npmrc

# Prune dependencies for Docker
RUN npx turbo prune --scope="app" --docker

# Installer stage
FROM base AS installer

# Install necessary packages
RUN apk add --no-cache libc6-compat && apk update

# Set working directory
WORKDIR /app

# Copy necessary files from builder stage
COPY .gitignore .gitignore
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/package-lock.json ./package-lock.json
COPY --from=builder /app/.npmrc ./.npmrc

# Install dependencies
RUN npm install turbo && npm install

# Build the application
RUN npx turbo run build --filter=app

# Runner stage
FROM base AS runner

# Set working directory
WORKDIR /app

# Set environment variables
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# Copy necessary files from builder and installer stages
COPY --from=builder /app/.npmrc ./.npmrc 
COPY --from=installer /app/apps/app/next.config.js ./next.config.js 
COPY --from=installer /app/apps/app/.next ./.next
COPY --from=installer /app/apps/app/package.json ./package.json

# Install production dependencies
RUN npm install

# Expose the application port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]

# Use a specific version of node for consistency
FROM node:18-alpine AS base

# Install npm globally
RUN npm install -g npm@10.2.4

# Builder stage
FROM base AS builder
RUN apk add --no-cache libc6-compat

# Set the working directory
WORKDIR /app

# Copy the application code
COPY ./apps/app ./apps/app

# Set up .npmrc
ARG NPM_AUTH_TOKEN
ENV NPM_AUTH_TOKEN=$NPM_AUTH_TOKEN
RUN echo "-strict=true" >> /app/.npmrc && \
    echo "save-prefix=\"\"" >> /app/.npmrc && \
    echo "//npm.pkg.github.com/:_authToken=$NPM_AUTH_TOKEN" >> /app/.npmrc && \
    echo "@maheshyadav7702:registry=https://npm.pkg.github.com" >> /app/.npmrc && \
    echo "registry=https://registry.npmjs.org" >> /app/.npmrc

# Install turbo globally
RUN npm install -g turbo

# Run turbo prune
RUN turbo prune --scope="app" --docker

RUN cat /path/to/turbo.json

# Add lockfile and package.json's of isolated subworkspace
FROM base AS installer
RUN apk add --no-cache libc6-compat
RUN apk update
WORKDIR /app
# First install the dependencies (as they change less often)
COPY .gitignore .gitignore
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/package-lock.json ./package-lock.json
COPY --from=builder /app/.npmrc ./.npmrc
RUN npm install turbo
RUN npm install
# Build the project
# COPY --from=builder /app/out/full/ .
# ARG NEXT_PUBLIC_CONTAINER_ENV_VAR



# Build the application
RUN npx turbo run build --filter=app

# Runner stage
FROM base AS runner

# Set working directory
WORKDIR /app

# Set environment variables
ENV NODE_ENV production
# ENV NEXT_TELEMETRY_DISABLED 1

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

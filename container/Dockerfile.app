FROM node:18-alpine AS base
RUN npm install -g npm@10.2.4

FROM base AS builder
RUN apk add --no-cache libc6-compat
RUN apk update
# Set working directory
WORKDIR /app
RUN npm install -g turbo@1.12.3
COPY package*.json ./
COPY turbo.json ./
COPY ./apps/app ./apps/app
ARG NPM_AUTH_TOKEN
ENV NPM_AUTH_TOKEN=$NPM_AUTH_TOKEN


RUN echo "engine-strict=true" >> /app/.npmrc && \
    echo "save-prefix=\"\"" >> /app/.npmrc && \
    echo "//npm.pkg.github.com/:_authToken=$NPM_AUTH_TOKEN" >> /app/.npmrc && \
    echo "@CareerEdgeDevOps:registry=https://npm.pkg.github.com" >> /app/.npmrc && \
    echo "registry=https://registry.npmjs.org" >> /app/.npmrc
RUN npx turbo prune --scope="app" --docker

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
# ENV NEXT_PUBLIC_CONTAINER_ENV_VAR=$NEXT_PUBLIC_CONTAINER_ENV_VAR
# ARG NEXT_PUBLIC_SIMPLE_VAR
# ENV NEXT_PUBLIC_SIMPLE_VAR=$NEXT_PUBLIC_CONTAINER_ENV_VAR
# ARG PUBLIC_NEXTCORE_API_URL
# ENV PUBLIC_NEXTCORE_API_URL=$PUBLIC_NEXTCORE_API_URL
# ARG PUBLIC_NEXTEMP_API_URL
# ENV PUBLIC_NEXTEMP_API_URL=$PUBLIC_NEXTEMP_API_URL
# ARG PUBLIC_NEXTCASE_API_URL
# ENV PUBLIC_NEXTCASE_API_URL=$PUBLIC_NEXTCASE_API_URL
# ARG NEXT_PUBLIC_EMPLOYER_UI_URL
# ENV NEXT_PUBLIC_EMPLOYER_UI_URL=$NEXT_PUBLIC_EMPLOYER_UI_URL
# ARG NEXT_PUBLIC_CASEMANAGEMENT_UI_URL
# ENV NEXT_PUBLIC_CASEMANAGEMENT_UI_URL=$NEXT_PUBLIC_CASEMANAGEMENT_UI_URL

# RUN echo "NEXT_PUBLIC_CONTAINER_ENV_VAR == $NEXT_PUBLIC_CONTAINER_ENV_VAR"

# RUN   sed -i "s|process.env.NEXT_PUBLIC_CONTAINER_ENV_VAR|'${NEXT_PUBLIC_SIMPLE_VAR}'|g" /app/apps/core-app-service/next.config.js 
# RUN   sed -i "s|process.env.PUBLIC_NEXTCORE_API_URL|'${PUBLIC_NEXTCORE_API_URL}'|g" /app/apps/core-app-service/next.config.js
# RUN   sed -i "s|process.env.PUBLIC_NEXTEMP_API_URL|'${PUBLIC_NEXTEMP_API_URL}'|g" /app/apps/core-app-service/next.config.js
# RUN   sed -i "s|process.env.PUBLIC_NEXTCASE_API_URL|'${PUBLIC_NEXTCASE_API_URL}'|g" /app/apps/core-app-service/next.config.js
# RUN   sed -i "s|process.env.NEXT_PUBLIC_EMPLOYER_UI_URL|'${NEXT_PUBLIC_EMPLOYER_UI_URL}'|g" /app/apps/core-app-service/next.config.js
# RUN   sed -i "s|process.env.NEXT_PUBLIC_CASEMANAGEMENT_UI_URL|'${NEXT_PUBLIC_CASEMANAGEMENT_UI_URL}'|g" /app/apps/core-app-service/next.config.js
# RUN echo "TEST1 $NEXT_PUBLIC_SIMPLE_VAR"
# RUN echo "TEST2 $NEXT_PUBLIC_CONTAINER_ENV_VAR"

RUN npx turbo run build --filter=app
# RUN npm ci --omit=dev && npm cache clean --force


FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1


# Don't run production as root
COPY --from=builder /app/.npmrc ./.npmrc 
COPY --from=installer /app/apps/app/next.config.js ./next.config.js 

# Automatically leverage output traces to reduce image size
COPY --from=installer /app/apps/app/.next ./.next
RUN true
COPY --from=installer /app/apps/app/package.json ./package.json
RUN true
#COPY --from=installer /app/apps/core-app-service/node_modules ./node_modules
RUN npm install

EXPOSE 3000

# ENV PORT 3030

CMD ["npm", "start"]

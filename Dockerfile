# Stage 1: Build Rust WASM
FROM rust:1.78 as wasm-builder

WORKDIR /app
RUN apt-get update && apt-get install -y pkg-config libssl-dev build-essential
RUN cargo install wasm-pack

COPY frontend/wasm ./frontend/wasm
COPY libraries ./libraries
COPY node-graph ./node-graph
COPY proc-macros ./proc-macros
COPY Cargo.toml Cargo.lock ./
COPY frontend/wasm/Cargo.toml ./frontend/wasm/Cargo.toml

WORKDIR /app/frontend/wasm
RUN wasm-pack build --release --target web

# Stage 2: Build Svelte Frontend
FROM node:20 as frontend-builder

WORKDIR /app/frontend

COPY frontend/package*.json ./
COPY frontend/tsconfig.json ./
COPY frontend/vite.config.ts ./
COPY frontend/.eslintrc.cjs ./
COPY frontend/.prettierrc ./
COPY frontend/package-installer.js ./
COPY frontend/public ./public
COPY frontend/src ./src
COPY frontend/assets ./assets
COPY frontend/wasm ./wasm

# Copy built WASM from previous stage
COPY --from=wasm-builder /app/frontend/wasm/pkg ./wasm/pkg

RUN npm ci
RUN npm run build

# Stage 3: Serve with Nginx
FROM nginx:alpine

COPY --from=frontend-builder /app/frontend/dist /usr/share/nginx/html

# Optional: custom nginx config for SPA routing
COPY website/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

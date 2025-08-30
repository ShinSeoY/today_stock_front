# ---------- build ----------
    FROM node:20-alpine AS build
    WORKDIR /app
    
    COPY package*.json ./
    RUN npm ci
    
    COPY . .
    # VITE_API_BASE_URL은 Actions에서 주입(혹은 --build-arg로도 가능)
    RUN npm run build
    
    # ---------- serve ----------
    FROM nginx:alpine
    # Ingress를 사용할 경우 Nginx는 정적파일만 서빙(프록시는 Ingress가 담당)
    # SPA 라우팅
    COPY nginx.conf /etc/nginx/conf.d/default.conf
    COPY --from=build /app/dist /usr/share/nginx/html
    
    EXPOSE 80
    CMD ["nginx", "-g", "daemon off;"]
    
FROM node:12.19.0 as nodejs

WORKDIR /app
COPY ./ /app/

RUN npm install
RUN npm run build

FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html
COPY --from=nodejs /app/public/ /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf

FROM nginx:alpine
COPY part_2_dev_api/chapter_08 /usr/share/nginx/html
EXPOSE 8080
RUN sed -i 's/listen       80;/listen 8080;/' /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]
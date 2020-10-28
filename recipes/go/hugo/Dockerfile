FROM klakegg/hugo:0.76.5-onbuild AS hugo

ARG RUNCOMMAND="hugo server"

FROM nginx
COPY --from=hugo /target /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf

RUN $RUNCOMMAND
CMD ["hugo", "server"]
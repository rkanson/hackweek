FROM node:12

ARG RUNCOMMAND="npm run build"

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .

RUN $RUNCOMMAND

CMD [ "npm", "start" ]

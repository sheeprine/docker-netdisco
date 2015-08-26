# docker-netdisco

## Usage:

Start a postgres database:

`docker run -d --name=pg-netdisco postgres`

Link it to netdisco:

`docker run -d --name=netdisco -e NETDISCO_WR_COMMUNITY="private" --link pg-netdisco:db -p 5000:5000 sheeprine/docker-netdisco`

Connect using your browser to http://<IP-of-docker-host>:5000/

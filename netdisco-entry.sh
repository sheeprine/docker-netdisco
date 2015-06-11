#!/usr/bin/env sh

DB_ENV_POSTGRES_USER=${DB_ENV_POSTGRES_USER:=postgres}
NETDISCO_DB_PASS="netdiscopass"
NETDISCO_DOMAIN=${NETDISCO_DOMAIN:='`hostname -d`'}
NETDISCO_RO_COMMUNITY=${NETDISCO_RO_COMMUNITY:='public'}

PSQL_OPTIONS="-h "$DB_PORT_5432_TCP_ADDR" -p "$DB_PORT_5432_TCP_PORT" -U $DB_ENV_POSTGRES_USER"

provision_netdisco_db() {
    psql $PSQL_OPTIONS -c "CREATE ROLE netdisco WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE password '$NETDISCO_DB_PASS'"
    psql $PSQL_OPTIONS -c "CREATE DATABASE netdisco OWNER netdisco"
}

check_postgres() {
    echo "*:*:*:$DB_ENV_POSTGRES_USER:$DB_ENV_POSTGRES_PASSWORD" > ~/.pgpass
    chmod 600 ~/.pgpass
    if [ -z `psql $PSQL_OPTIONS -tAc "SELECT 1 FROM pg_roles WHERE rolname='netdisco'"` ]; then
        provision_netdisco_db
    fi
}

set_environment() {
    ENV_FILE="$NETDISCO_HOME/environments/deployment.yml"
    mkdir $NETDISCO_HOME/environments
    cp $NETDISCO_HOME/perl5/lib/perl5/auto/share/dist/App-Netdisco/environments/deployment.yml $ENV_FILE
    chmod 600 $ENV_FILE
    sed -i "s/user: 'changeme'/user: 'netdisco'/" $ENV_FILE
    sed -i "s/pass: 'changeme'/pass: '$NETDISCO_DB_PASS'/" $ENV_FILE
    sed -i "s/#*host: 'localhost'/host: '${DB_PORT_5432_TCP_ADDR};port=${DB_PORT_5432_TCP_PORT}'/" $ENV_FILE
    sed -i "s/#*domain_suffix: '.example.com'/domain_suffix: '$NETDISCO_DOMAIN'/" $ENV_FILE

    sed -i "s/community: 'public'/community: '$NETDISCO_RO_COMMUNITY'/" $ENV_FILE

    if [ -n $NETDISCO_WR_COMMUNITY ]; then
        sed -i "/snmp_auth:/a\  - tag: 'default_v2_for_write'" $ENV_FILE
        sed -i "/^  - tag: 'default_v2_for_write/a\    write: true" $ENV_FILE
        sed -i "/^  - tag: 'default_v2_for_write/a\    read: false" $ENV_FILE
        sed -i "/^  - tag: 'default_v2_for_write/a\    community: '$NETDISCO_WR_COMMUNITY'" $ENV_FILE
    fi

    sed -i "/#schedule:/, /when: '20 23 \* \* \*'/ s/#//" $ENV_FILE
}

check_environment() {
    if [ ! -d $NETDISCO_HOME/environments ]; then
        set_environment
    fi
}

check_postgres
check_environment
sed -i "s/new('netdisco')/new('netdisco', \\*STDIN, \\*STDOUT)/" $NETDISCO_HOME/perl5/bin/netdisco-deploy
cat | netdisco-deploy << EOF
y
y
admin
password
y
y
EOF

netdisco-web start &
netdisco-daemon start
tail -f $NETDISCO_HOME/logs/netdisco-daemon.log

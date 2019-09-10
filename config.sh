psql postgres -f sql/sat2.sql

# agregar esta línea en /etc/postgresql/10/main/pg_hba.conf
# "local   sat2             sat2                                   password"
# reiniciar postresql


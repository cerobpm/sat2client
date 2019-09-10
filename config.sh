psql postgres -f sql/sat2.sql

# agregar esta línea en /etc/postgresql/10/main/pg_hba.conf
# "local   sat2             sat2                                   password"
# reiniciar postresql

nodejs index.js Sat2:GetEquipos $user $pass --save

psql sat2 -c "update equipos set \"idGrupo\"=2 where descripcion~'ZPrueba'"
psql sat2 -c "update equipos set \"idGrupo\"=3 where descripcion~'RMA'"

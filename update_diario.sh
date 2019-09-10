### update diario ###

sd=$(date -d "now - 7 days" +%Y-%m-%d)
ed=$(date -d "tomorrow" +%Y-%m-%d)

nodejs index.js Sat2:GetEquipos $user $pass
nodejs index.js Sat2:GetHistoricosPorFechas $user $pass $sd $ed
nodejs index.js Sat2:updateCount all $sd $ed
nodejs index.js Sat2:updateReportes anio $sd $ed
nodejs index.js Sat2:updateReportes mes $sd $ed
nodejs index.js Sat2:updateReportes dia $sd $ed

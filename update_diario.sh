### update diario ###

sd=$(date -d "now - 7 days" +%Y-%m-%d)
ed=$(date -d "tomorrow" +%Y-%m-%d)

nodejs index.js Sat2:GetEquipos RHN 1R2H
nodejs index.js Sat2:GetHistoricosPorFechas RHN 1R2H $sd $ed
nodejs index.js Sat2:updateCount all $sd $ed
nodejs index.js Sat2:updateReportes anio $sd $ed
nodejs index.js Sat2:updateReportes mes $sd $ed
nodejs index.js Sat2:updateReportes dia $sd $ed

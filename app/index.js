'use strict'

const program = require('commander')
const inquirer = require('inquirer')
const { Pool, Client } = require('pg')
const pool = new Pool({
  user: 'sat2',
  host: 'localhost',
  database: 'sat2',
  password: 'sat2',
  port: 5432
})

const Sat2 = require('./sat2')
const sat2 = new Sat2()
const Sat2db = require('./sat2db')
const CRUD = new Sat2db.CRUD(pool)

program
  .version('0.0.1')
  .description('Data providers accessors');

program
  .command('Sat2:GetEquipos <user> <pass>')
  .alias('g')
  .description('Get equipos SAT2')
  .option('-s, --save', 'save into DB')
  .action((user, pass, cmdObj) => {
    sat2.GetEquipos(user, pass)
    .then(result=> {
		//~ console.log(result)
	  if(! Array.isArray(result)) {
		  console.error("result no es un array!")
		  return
	  }
	  console.log("Found "+result.length+" Equipos")
	  result.map((it,index)=> {
		  console.log("["+index+"] idEquipo:"+it.idEquipo+", descripcion:"+it.descripcion+", lat:"+it.lat+", lng:"+it.lng+", NroSerie:"+it.NroSerie+", fechaAlta:"+it.fechaAlta)
		  if(cmdObj.save) {
			  const equipo = new Sat2db.Equipo(it.idEquipo,it.descripcion,-1*it.lat,-1*it.lng,it.NroSerie,it.fechaAlta)
			  console.log(equipo.toString())
			  CRUD.insertEquipos(equipo)
			  .then(r=>{
				  //~ console.log("Equipo guardado")
				  r.map((equipo,i)=>{
					console.log(equipo.toString())
				  })
				  console.log(r.length + " equipos guardados")
			  })
			  .catch(e=>{
				  console.log("Error al intentar guardar Equipo")
				  console.error(e)
			  })
		  }
		  if(! it.sensores) {
			  console.error("sensores property not found in index "+index)
			  return
		  }
		  it.sensores.map( (s,i)=> {
			  console.log( i + "    idEquipo:"+ it.idEquipo+", idSensor:"+s.idSensor+", nombre:" + s.nombre)
		  })
	  })
	})
	.catch(e=>{
		console.error(e)
	})
  });

program
  .command('Sat2:Auth <user> <pass>')
  .alias('a')
  .description('SAT2: autenticar usuario')
  .action( (user, pass) => {
	sat2.AutenticarUsuario(user,pass)
	.then(result=> {
		console.log(result)
	})
	.catch(e=> {
		console.log("Error de autenticación")
		console.error(e)
	})
  })

program
  .command('Sat2:GetInstantaneosDeEquipo <user> <pass> <idEquipo>')
  .alias('i')
  .description('SAT2: vizualizar los datos instantáneos de los equipos')
  .action((user, pass, idEquipo) => {
    sat2.GetInstantaneosDeEquipo(user, pass, idEquipo)
    .then(result=> {
		console.log(result)
	})
	.catch(e=>{
		console.error(e)
	})
  });

program
  .command('Sat2:GetHistoricosDeEquipoPorSensor <user> <pass> <idEquipo> <idSensor> <fechaDesde> <fechaHasta>')
  .alias('h')
  .description('para hacer los graficos y las tablas con datos históricos')
  .action((user, pass, idEquipo,idSensor,fechaDesde,fechaHasta) => {
	sat2.GetHistoricosDeEquipoPorSensor(user,pass,idEquipo,idSensor,fechaDesde,fechaHasta)
    .then(result=> {
		console.log(result)
	})
	.catch(e=>{
		console.error(e)
	})
  });

program
  .command('Sat2:GetMaximosYMinimos <user> <pass> <idEquipo> <tipoDeConsulta>')
  .alias('m')
  .description('Acumulada is calculated instead of average (Promedio) for any rainfall data (Sensor name contains “Lluvia” or “Precipitacion”). All -999.9 values have been excluded from calculations. Sensors with no data for this period return “valoresSensor = [ ]”. “tipoDeConsulta” is for time period requested: 1 = Hoy, 2=Ayer, 3 = Mes actual, 4 = Mes anterior.')
  .action((user, pass, idEquipo, tipoDeConsulta) => {
	console.log("idEquipo:"+idEquipo)
	sat2.GetMaximosYMinimos(user,pass,idEquipo,tipoDeConsulta)
    .then(result=> {
	  //~ console.log(body)
	  console.log("periodo:"+result.periodo)
	  if(result.Datos) {
		  console.log("Found "+result.Datos.length+" sensores")
		  result.Datos.map( (it,index) => {
			  console.log(it)
		  })
	  }
	})
	.catch(e=>{
		console.error(e)
	})
  });

program
  .command('Sat2:ReadEquipos [idEquipo...]')
  .alias('e')
  .description('Lee equipos de base de datos')
  .action( idEquipo => {
	  if(idEquipo.length == 1) {
		  idEquipo = idEquipo[0]
	  } else if (idEquipo.length == 0) {
		idEquipo = undefined
	  }  
	  CRUD.readEquipos(idEquipo)
	  .then(res=> {
		  res.map( (equipo,i) => {
			  console.log(equipo.toString())
		  })
		  console.log("Se encontraron " + res.length + " equipos")
	  })
	  .catch(e=> {
		  console.error(e)
	  })
  });

program
  .command('Sat2:DeleteEquipos [idEquipo...]')
  .alias('D')
  .description('Elimina equipos de base de datos')
  .action( idEquipo => {
	  if(idEquipo.length == 1) {
		  idEquipo = idEquipo[0]
	  } else if (idEquipo.length == 0) {
		idEquipo = undefined
	  }
	  CRUD.readEquipos(idEquipo)
	  .then(res=> {
		  console.log("Se encontraron " + res.length + " equipos. Desea eliminarlos?")
		  inquirer.prompt([
			{ type: 'input', name: 'confirm', message: '(y/n)'}
		  ]).then(answers=> {
			  if(answers.confirm.match(/^[yYsStTvV1]/)) { 
				  CRUD.deleteEquipos(idEquipo)
				  .then(res=> {
					  res.map( (equipo,i) => {
						  console.log(equipo.toString())
					  })
					  console.log("Se eliminaron " + res.length + " equipos")
				  })
				  .catch(e=> {
					  console.error(e)
				  })
			  } else {
				  console.log("Abortado por el usuario")
			  }
		  })
	  })
	  .catch(e=>{
		  console.log(e)
	  })
  });




program.parse(process.argv);

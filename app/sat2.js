'use strict'

const request = require('request')
const internal = {}

module.exports = internal.sat2 = class{
	constructor(){
        //~ console.log("Initialize sat2 object");
    }
	AutenticarUsuario(user,pass,cookieJar) {
		return new Promise( (resolve, reject) => {
			request.post({url:'http://utr.gsm.ina.gob.ar:5667/SAT2Rest/api/AutenticarUsuario',jar:cookieJar, 
			  json: {
				nombreDeUsuario: user,
				clave: pass
			  }
			}, (error, res, body) => {
			  if (error) {
				console.error(error)
				reject(error)
				return
			  }
			  console.log(`statusCode: ${res.statusCode}`)
			  console.log(body)
			  resolve(body)
			})
		})
	}

	RecuperarEquipos(idCliente,cookieJar) {
		return new Promise( (resolve, reject) => {
			request.post({url:'http://utr.gsm.ina.gob.ar:5667/SAT2Rest/api/RecuperarEquipos',jar:cookieJar, json: {
				idCliente: idCliente
			  }
			}, (error, res, body) => {
			  if (error) {
				console.error(error)
				reject(error)
				return
			  }
			  console.log(`statusCode: ${res.statusCode}`)
			  //~ console.log(body)
			  resolve(body)
			})
		})
	}

	RecuperarInstantaneosDeEquipo(idEquipo,cookieJar) {
		return new Promise( (resolve, reject) => {
			request.post({url:'http://utr.gsm.ina.gob.ar:5667/SAT2Rest/api/RecuperarInstantaneosDeEquipo',jar:cookieJar, json: {
				idEquipo: idEquipo
			  }
			}, (error, res, body) => {
			  if (error) {
				console.error(error)
				reject(error)
				return
			  }
			  console.log(`statusCode: ${res.statusCode}`)
			  //~ console.log(body)
			  console.log(body.fechaUltimaActualizacionDatos)
			  console.log(body.datosSensores)
			  resolve(body)
			})
		})
	}
	
	RecuperarHistoricosDeEquipoPorSensor(idEquipo,idSensor,fechaDesde,fechaHasta,cookieJar) {
		return new Promise( (resolve, reject) => {
			request.post({url:'http://utr.gsm.ina.gob.ar:5667/SAT2Rest/api/RecuperarHistoricosDeEquipoPorSensor',jar:cookieJar, json: {
				idEquipo: idEquipo,
				idSensor: idSensor,
				fechaDesde: fechaDesde,
				fechaHasta: fechaHasta
			  }
			}, (error, res, body) => {
			  if (error) {
				console.error(error)
				reject(error)
				return
			  }
			  console.log(`statusCode: ${res.statusCode}`)
			  console.log(body)
			  resolve(body)
			})
		})
	}
	RecuperarMaximosYMinimos(idEquipo,tipoDeConsulta,cookieJar) {
		return new Promise( (resolve, reject) => {
			request.post({url:'http://utr.gsm.ina.gob.ar:5667/SAT2Rest/api/RecuperarMaximosYMinimos',jar:cookieJar, json: {
				idEquipo: idEquipo,
				tipoDeConsulta: tipoDeConsulta
			  }
			}, (error, res, body) => {
			  if (error) {
				console.error(error)
				reject(error)
				return
			  }
			  console.log(`statusCode: ${res.statusCode}`)
			  resolve(body)
			})
		})
	}
	

	GetEquipos(user,pass) {
		var cookieJar = request.jar()
		return this.AutenticarUsuario(user,pass,cookieJar)
		.then(result=> {
			console.log(result.idCliente)
			return this.RecuperarEquipos(result.idCliente,cookieJar)
		})
		.catch(e=>{
			console.log("falló autenticación")
		})
	}

	GetInstantaneosDeEquipo(user,pass,idEquipo) {
		var cookieJar = request.jar()
		return this.AutenticarUsuario(user,pass,cookieJar)
		.then(result=> {
			//~ console.log(result.idCliente)
			return this.RecuperarInstantaneosDeEquipo(idEquipo,cookieJar)
		})
		.catch(e=>{
			console.log("falló autenticación")
		})
	}
	
	GetHistoricosDeEquipoPorSensor(user,pass,idEquipo,idSensor,fechaDesde,fechaHasta) {
		var cookieJar = request.jar()
		return this.AutenticarUsuario(user,pass,cookieJar)
		.then(result=> {
			//~ console.log(result.idCliente)
			return this.RecuperarHistoricosDeEquipoPorSensor(idEquipo,idSensor,fechaDesde,fechaHasta,cookieJar)
		})
		.catch(e=>{
			console.log("falló autenticación")
		})
	}
	GetMaximosYMinimos(user,pass,idEquipo,tipoDeConsulta) {
		var cookieJar = request.jar()
		return this.AutenticarUsuario(user,pass,cookieJar)
		.then(result=> {
			//~ console.log(result.idCliente)
			return this.RecuperarMaximosYMinimos(idEquipo,tipoDeConsulta,cookieJar)
		})
		.catch(e=>{
			console.error(e)
		})
	}
}

  
    
// module.exports { AutenticarUsuario, RecuperarEquipos, GetSat2Equipos, GetSat2InstantaneosDeEquipo }

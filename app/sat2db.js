'use strict'

const internal = {}
const { Pool, Client } = require('pg')

internal.Equipo = class{
	constructor(idEquipo, descripcion, lat, lng, NroSerie, fechaAlta){
        //~ validtypes:(int, string, float, float, string|int, Date|string);
        if(!idEquipo || !descripcion || !lat || !lng) {
			throw "faltan argumentos para crear Equipo"
			return
		}
        if(! parseInt(idEquipo)) {
			throw "idEquipo incorrecto"
			return
		}
		if(!parseFloat(lat) || !parseFloat(lng)) {
			throw "lat o lng incorrecto"
			return
		}
        this.idEquipo =  parseInt(idEquipo)
        this.descripcion = String(descripcion)
        this.lng = parseFloat(lng)
        this.lat = parseFloat(lat)
        this.NroSerie = (NroSerie) ? String(NroSerie) : null
        if(fechaAlta) {
			if(fechaAlta instanceof Date) {
				this.fechaAlta = fechaAlta
			} else {
				var m = fechaAlta.match(/\d\d?\/\d\d?\/\d\d\d\d\s\d\d?\:\d\d\:\d\d/)
				if(m) {
					var s = m[0].split(" ")
					var d = s[0].split("/")
					var t = s[1].split(":")
					this.fechaAlta = new Date(
						parseInt(d[2]), 
						parseInt(d[1]-1), 
						parseInt(d[0]),
						parseInt(t[0]),
						parseInt(t[1]),
						parseInt(t[2])
					)
				} else {
					var m2 = new Date(fechaAlta)
					if(m2 == 'Invalid Date') {
						throw "fechaAlta incorrecta"
						return
					} else {
						this.fechaAlta = m2
					}
				}
			}
		} else {
			this.fechaAlta = null
		}
    }
    toString(sep=",") {
		return this.idEquipo + sep + this.descripcion + sep + this.lat + sep + this.lng + sep + this.NroSerie + sep + ((this.fechaAlta) ? this.fechaAlta.toISOString() : "null")
	}
}
    
internal.CRUD = class{
	constructor(pool) {
		if(! pool instanceof Pool) {
			console.error("pool incorrecto, debe ser instancia de Pool")
			throw "pool incorrecto, debe ser instancia de Pool"
			return
		}
		this.pool = pool
	}
			
	insertEquipos(equipos) {
		return new Promise( (resolve, reject) => {
			if(!equipos) {
				throw "Falta argumento equipos Equipo[]"
				return
			}
			const stmt = "INSERT INTO equipos \
			VALUES ($1,$2,st_setsrid(st_point($3,$4),4326),$5,$6) \
			ON CONFLICT (\"idEquipo\") \
			DO UPDATE SET descripcion=$2, \
						  geom=st_setsrid(st_point($3,$4),4326), \
						  \"NroSerie\"=$5, \
						  \"fechaAlta\"=$6 \
			RETURNING  \"idEquipo\", descripcion, st_y(geom) AS lng, st_x(geom) AS lat, \"NroSerie\", to_char(\"fechaAlta\", 'YYYY-MM-DD\"T\"HH24:MI:SS') AS \"fechaAlta\" "
			var insertlist = [] 
			if(Array.isArray(equipos)) {
				for(var i =0; i< equipos.length; i++) {
					if(! equipos[i] instanceof internal.Equipo) {
						console.error("equipo " + i + " incorrecto, debe ser instancia de Equipo")
						throw "equipo " + i + " incorrecto, debe ser instancia de Equipo"
						return
					}
					insertlist.push(this.pool.query(stmt,[equipos[i].idEquipo, equipos[i].descripcion,equipos[i].lng,equipos[i].lat,equipos[i].NroSerie, equipos[i].fechaAlta]))
				}
			} else {
				if(! equipos instanceof internal.Equipo) {
					console.error("equipo " + i + " incorrecto, debe ser instancia de Equipo")
					throw "equipo " + i + " incorrecto, debe ser instancia de Equipo"
					return
				} else {
					insertlist.push(this.pool.query(stmt,[equipos.idEquipo, equipos.descripcion,equipos.lng,equipos.lat,equipos.NroSerie, equipos.fechaAlta]))
				}
			}
			Promise.all(insertlist)
			.then(result => {
				var equipos = []
				for(var j=0;j<result.length;j++) {
					if(result[j].rows) {
						for(var i=0; i<result[j].rows.length;i++) {
							const equipo = new internal.Equipo(result[j].rows[i].idEquipo,result[j].rows[i].descripcion,result[j].rows[i].lat,result[j].rows[i].lng,result[j].rows[i].NroSerie, result[j].rows[i].fechaAlta) 
							equipos.push(equipo)
						}
					} else {
						console.log("No rows inserted in query "+j)
					}
				}
				resolve(equipos)
			})
			.catch(e=>{
				console.error(e)
				reject(e)
			})
		})
	}
	
	readEquipos(idEquipo) {
		return new Promise( (resolve, reject) => {
			// idEquipo int|int[]|string default null
			var filter = ""
			if(Array.isArray(idEquipo)) {
				for(var i=0; i<idEquipo.length;i++) {
					if(!parseInt(idEquipo[i])) {
						throw "idEquipo incorrecto"
						return
					}
					idEquipo[i] = parseInt(idEquipo[i])
				}
				filter = "WHERE \"idEquipo\" = ANY (ARRAY[" + idEquipo.join(",") + "])"
			} else if (parseInt(idEquipo)) {
				filter = "WHERE \"idEquipo\" = " + parseInt(idEquipo)
			} else {
				idEquipo = idEquipo.toString()
				if(idEquipo.match(/[';]/)) {
					throw "Invalid characters for string matching"
					return
				}
				filter = "WHERE lower(descripcion) ~ lower('" + idEquipo + "')" 
			}
			console.log("filter")
			console.log(filter)
			this.pool.query("SELECT \"idEquipo\", descripcion, st_y(geom) AS lng, st_x(geom) AS lat, \"NroSerie\", to_char(\"fechaAlta\", 'YYYY-MM-DD\"T\"HH24:MI:SS') AS \"fechaAlta\" FROM equipos " + filter)
			.then(res=>{
				var equipos=[]
				if(res.rows) {
					for(var i=0; i<res.rows.length;i++) {
						const equipo = new internal.Equipo(res.rows[i].idEquipo,res.rows[i].descripcion,res.rows[i].lat,res.rows[i].lng,res.rows[i].NroSerie, res.rows[i].fechaAlta) 
						equipos.push(equipo)
					}
				} else {
					console.log("No equipos found!")
				}
				resolve(equipos)
			})
			.catch(e=> {
				console.error("Query error")
				reject(e)
			})
		})
	}
	
	deleteEquipos(idEquipo) {
		return new Promise( (resolve, reject) => {
			// idEquipo int|int[]|string default null
			var filter = ""
			if(Array.isArray(idEquipo)) {
				for(var i=0; i<idEquipo.length;i++) {
					if(!parseInt(idEquipo[i])) {
						throw "idEquipo incorrecto"
						return
					}
					idEquipo[i] = parseInt(idEquipo[i])
				}
				filter = "WHERE \"idEquipo\" = ANY (ARRAY[" + idEquipo.join(",") + "])"
			} else if (parseInt(idEquipo)) {
				filter = "WHERE \"idEquipo\" = " + parseInt(idEquipo)
			} else {
				idEquipo = idEquipo.toString()
				if(idEquipo.match(/[';]/)) {
					throw "Invalid characters for string matching"
					return
				}
				filter = "WHERE lower(descripcion) ~ lower('" + idEquipo + "')" 
			}
			console.log("filter")
			console.log(filter)
			this.pool.query("DELETE FROM equipos " + filter + " RETURNING \"idEquipo\", descripcion, st_y(geom) AS lng, st_x(geom) AS lat, \"NroSerie\", to_char(\"fechaAlta\", 'YYYY-MM-DD\"T\"HH24:MI:SS') AS \"fechaAlta\" ")
			.then(res=>{
				var equipos=[]
				if(res.rows) {
					for(var i=0; i<res.rows.length;i++) {
						const equipo = new internal.Equipo(res.rows[i].idEquipo,res.rows[i].descripcion,res.rows[i].lat,res.rows[i].lng,res.rows[i].NroSerie, res.rows[i].fechaAlta) 
						equipos.push(equipo)
					}
				} else {
					console.log("No equipos found!")
				}
				resolve(equipos)
			})
			.catch(e=> {
				console.error("Query error")
				reject(e)
			})
		})
	}
	
}


module.exports = internal

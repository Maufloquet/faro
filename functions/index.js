"use strict";

const admin = require("firebase-admin");
admin.initializeApp();

// Schedulers
exports.syncFogoCruzado = require("./lib/fogoCruzadoSync").syncFogoCruzado;

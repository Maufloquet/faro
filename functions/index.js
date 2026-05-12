"use strict";

const admin = require("firebase-admin");
admin.initializeApp();

// Schedulers
exports.syncFogoCruzado = require("./lib/fogoCruzadoSync").syncFogoCruzado;
exports.ingestNewsBahia = require("./lib/newsIngest").ingestNewsBahia;
exports.cleanupOccurrences = require("./lib/cleanupOccurrences").cleanupOccurrences;

// HTTP (manual one-shot)
exports.backfillFogoCruzado = require("./lib/fogoCruzadoBackfill").backfillFogoCruzado;

// Firestore triggers
exports.onOccurrenceCreated = require("./lib/proximityAlert").onOccurrenceCreated;

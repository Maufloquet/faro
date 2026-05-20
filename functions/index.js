"use strict";

const admin = require("firebase-admin");
admin.initializeApp();

// Schedulers
exports.syncFogoCruzado = require("./lib/fogoCruzadoSync").syncFogoCruzado;
exports.ingestNewsBahia = require("./lib/newsIngest").ingestNewsBahia;
exports.ingestOsmNotes = require("./lib/osmNotesIngest").ingestOsmNotes;
exports.cleanupOccurrences = require("./lib/cleanupOccurrences").cleanupOccurrences;

// HTTP (manual one-shot)
exports.backfillFogoCruzado = require("./lib/fogoCruzadoBackfill").backfillFogoCruzado;
exports.backfillDedup = require("./lib/dedupBackfill").backfillDedup;
exports.fetchOsmBusStops = require("./lib/osmFetch").fetchOsmBusStops;

// HTTP público — API pra pesquisadores credenciados (auth via API key
// gerenciada em /research_keys/{key}). Documentação: docs/parcerias/.
exports.getOccurrences = require("./lib/researchApi").getOccurrences;

// Firestore triggers
exports.onOccurrenceCreated = require("./lib/proximityAlert").onOccurrenceCreated;
exports.onContestationCreated =
  require("./lib/contestationAggregator").onContestationCreated;

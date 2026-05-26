"use strict";

const admin = require("firebase-admin");
admin.initializeApp();

// Schedulers
exports.syncFogoCruzado = require("./lib/fogoCruzadoSync").syncFogoCruzado;
exports.ingestNewsBahia = require("./lib/newsIngest").ingestNewsBahia;
exports.ingestOsmNotes = require("./lib/osmNotesIngest").ingestOsmNotes;
exports.syncOsmInfra = require("./lib/osmInfraIngest").syncOsmInfra;
exports.cleanupOccurrences = require("./lib/cleanupOccurrences").cleanupOccurrences;
exports.aggregateHistoricalBaseline =
  require("./lib/historicalBaseline").aggregateHistoricalBaseline;
exports.aggregateAdminMetrics =
  require("./lib/adminMetrics").aggregateAdminMetrics;
exports.aggregateNarratives =
  require("./lib/narrativeAggregator").aggregateNarratives;
exports.dailyDigest =
  require("./lib/dailyDigest").dailyDigest;
exports.expireReports = require("./lib/expireReports").expireReports;
exports.watchRoutes = require("./lib/watchRoutes").watchRoutes;

// HTTP (manual one-shot)
exports.backfillFogoCruzado = require("./lib/fogoCruzadoBackfill").backfillFogoCruzado;
exports.backfillDedup = require("./lib/dedupBackfill").backfillDedup;
exports.backfillEmbeddings = require("./lib/embedBackfill").backfillEmbeddings;
exports.fetchOsmBusStops = require("./lib/osmFetch").fetchOsmBusStops;
exports.fetchOsmInfra = require("./lib/osmInfraIngest").fetchOsmInfra;

// HTTP público — API pra pesquisadores credenciados (auth via API key
// gerenciada em /research_keys/{key}). Documentação: docs/parcerias/.
exports.getOccurrences = require("./lib/researchApi").getOccurrences;

// Callable (invocado pelo app autenticado)
exports.deleteAccountCascade =
  require("./lib/deleteAccount").deleteAccountCascade;
exports.exportUserData = require("./lib/exportUserData").exportUserData;

// Firestore triggers
exports.onOccurrenceCreated = require("./lib/proximityAlert").onOccurrenceCreated;
exports.onContestationWritten =
  require("./lib/contestationAggregator").onContestationWritten;
exports.onReportVoteWritten =
  require("./lib/reportVoteAggregator").onReportVoteWritten;

"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/historicalBaseline");
const { aggregateBaseline, regionKey } = _internal;

const NOW = new Date("2026-05-21T12:00:00Z");

function dayAgo(n) {
  return new Date(NOW.getTime() - n * 24 * 60 * 60 * 1000);
}

const baseOpts = {
  windowDays: 90,
  recentWindowDays: 7,
  now: NOW,
};

describe("historicalBaseline.aggregateBaseline", () => {
  it("retorna objeto vazio pra lista vazia", () => {
    assert.deepEqual(aggregateBaseline([], baseOpts), {});
  });

  it("ignora occurrences sem neighborhood (granularidade da UI)", () => {
    const out = aggregateBaseline(
      [
        { city: "Salvador", state: "BA", mainReason: "x", date: dayAgo(3) },
        {
          neighborhood: "Pituba",
          city: "Salvador",
          state: "BA",
          mainReason: "x",
          date: dayAgo(3),
        },
      ],
      baseOpts,
    );
    const keys = Object.keys(out);
    assert.equal(keys.length, 1);
    assert.equal(out[keys[0]].neighborhood, "Pituba");
  });

  it("agrupa por (state, city, neighborhood) — bairros homônimos em cidades diferentes não se misturam", () => {
    const out = aggregateBaseline(
      [
        {
          neighborhood: "Centro",
          city: "Salvador",
          state: "BA",
          mainReason: "x",
          date: dayAgo(1),
        },
        {
          neighborhood: "Centro",
          city: "Lauro de Freitas",
          state: "BA",
          mainReason: "x",
          date: dayAgo(1),
        },
      ],
      baseOpts,
    );
    assert.equal(Object.keys(out).length, 2);
  });

  it("calcula weeklyAverage = (total/windowDays)*7 arredondado a 2 casas", () => {
    const occ = Array.from({ length: 27 }, (_, i) => ({
      neighborhood: "Pituba",
      city: "Salvador",
      state: "BA",
      mainReason: "x",
      date: dayAgo(i * 3),
    }));
    const out = aggregateBaseline(occ, baseOpts);
    const r = out[Object.keys(out)[0]];
    assert.equal(r.totalOccurrences, 27);
    assert.equal(r.weeklyAverage, 2.1);
  });

  it("recentWeekCount conta só os últimos 7 dias", () => {
    const occ = [
      ...Array.from({ length: 5 }, () => dayAgo(2)),
      ...Array.from({ length: 5 }, () => dayAgo(20)),
    ].map((d) => ({
      neighborhood: "Pituba",
      city: "Salvador",
      state: "BA",
      mainReason: "x",
      date: d,
    }));
    const out = aggregateBaseline(occ, baseOpts);
    const r = out[Object.keys(out)[0]];
    assert.equal(r.recentWeekCount, 5);
    assert.equal(r.totalOccurrences, 10);
  });

  it("trend=insufficient_data quando total < MIN_OCCURRENCES_FOR_TREND", () => {
    const occ = Array.from({ length: 3 }, () => ({
      neighborhood: "BairroPequeno",
      city: "Salvador",
      state: "BA",
      mainReason: "x",
      date: dayAgo(2),
    }));
    const out = aggregateBaseline(occ, baseOpts);
    assert.equal(Object.values(out)[0].trend, "insufficient_data");
  });

  it("trend=up quando semana recente está bem acima da média", () => {
    // ~1 relato/sem na média (13 relatos em 90d), semana recente tem 10 → up
    const occ = [
      ...Array.from({ length: 10 }, () => dayAgo(2)),
      ...Array.from({ length: 3 }, (_, i) => dayAgo(20 + i * 10)),
    ].map((d) => ({
      neighborhood: "Pituba",
      city: "Salvador",
      state: "BA",
      mainReason: "x",
      date: d,
    }));
    const out = aggregateBaseline(occ, baseOpts);
    assert.equal(Object.values(out)[0].trend, "up");
  });

  it("trend=down quando semana recente está bem abaixo da média", () => {
    // 20 relatos espalhados na janela, 0 na semana recente → down
    const occ = Array.from({ length: 20 }, (_, i) => ({
      neighborhood: "Pituba",
      city: "Salvador",
      state: "BA",
      mainReason: "x",
      date: dayAgo(20 + i * 3),
    }));
    const out = aggregateBaseline(occ, baseOpts);
    assert.equal(Object.values(out)[0].trend, "down");
  });

  it("trend=stable quando recente está perto da média", () => {
    // ~7 relatos/sem na média (90 relatos em 90d), semana recente tem 7 → stable
    const occ = Array.from({ length: 90 }, (_, i) => ({
      neighborhood: "Pituba",
      city: "Salvador",
      state: "BA",
      mainReason: "x",
      date: dayAgo(i),
    }));
    const out = aggregateBaseline(occ, baseOpts);
    assert.equal(Object.values(out)[0].trend, "stable");
  });

  it("topReasons retorna até 3 motivos ordenados por contagem", () => {
    const make = (reason, n) =>
      Array.from({ length: n }, () => ({
        neighborhood: "Pituba",
        city: "Salvador",
        state: "BA",
        mainReason: reason,
        date: dayAgo(10),
      }));
    const occ = [
      ...make("tiroteio", 8),
      ...make("operação", 3),
      ...make("disputa", 5),
      ...make("outro", 1),
    ];
    const out = aggregateBaseline(occ, baseOpts);
    const r = Object.values(out)[0];
    assert.equal(r.topReasons.length, 3);
    assert.deepEqual(r.topReasons.map((x) => x.reason), [
      "tiroteio",
      "disputa",
      "operação",
    ]);
  });

  it("mainReason ausente vira 'outros'", () => {
    const occ = Array.from({ length: 5 }, () => ({
      neighborhood: "Pituba",
      city: "Salvador",
      state: "BA",
      mainReason: null,
      date: dayAgo(2),
    }));
    const out = aggregateBaseline(occ, baseOpts);
    assert.equal(Object.values(out)[0].topReasons[0].reason, "outros");
  });

  it("descarta occurrences sem date", () => {
    const out = aggregateBaseline(
      [
        {
          neighborhood: "Pituba",
          city: "Salvador",
          state: "BA",
          mainReason: "x",
          date: null,
        },
        {
          neighborhood: "Pituba",
          city: "Salvador",
          state: "BA",
          mainReason: "x",
          date: dayAgo(2),
        },
      ],
      baseOpts,
    );
    assert.equal(Object.values(out)[0].totalOccurrences, 1);
  });
});

describe("historicalBaseline.regionKey", () => {
  it("normaliza acentos e separadores", () => {
    const key = regionKey({
      state: "BA",
      city: "Salvador",
      neighborhood: "São Caetano",
    });
    assert.equal(key, "ba__salvador__sao-caetano");
  });

  it("fallback '_' pra campos ausentes", () => {
    const key = regionKey({ state: null, city: null, neighborhood: "Pituba" });
    // state="_" + sep "__" + city="_" + sep "__" + neighborhood="pituba"
    assert.equal(key, "______pituba");
  });

  it("é determinístico", () => {
    const a = regionKey({
      state: "BA",
      city: "Salvador",
      neighborhood: "Pituba",
    });
    const b = regionKey({
      state: "BA",
      city: "Salvador",
      neighborhood: "Pituba",
    });
    assert.equal(a, b);
  });
});

// Draws a score with OpenSheetMusicDisplay and lets the app colour notes by "measure:midi:onset" keys.
(function () {
  "use strict";
  var COLORS = { current: "#1565c0", correct: "#2e7d32", wrong: "#c62828", missed: "#c62828", late: "#ef6c00", early: "#ef6c00", plain: "#000000" };
  var osmd = null;
  var noteMap = {};      // key -> [svg elements]
  var measureBoxes = []; // per measure: [{x, y, w, h}] one per staff line it appears on
  var marked = {};       // key -> state
  var current = [];
  var dimmed = [];

  function post(message) {
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.notation) {
        window.webkit.messageHandlers.notation.postMessage(message);
      }
    } catch (e) { /* not inside the app */ }
    window.lastNotationMessage = message;
  }

  function gcd(a, b) { a = Math.abs(a); b = Math.abs(b); while (b) { var t = b; b = a % b; a = t; } return a || 1; }

  function fractionKey(f) {
    var den = f.Denominator || f.denominator || 1;
    var num = (f.Numerator || f.numerator || 0) + (f.WholeValue || f.wholeValue || 0) * den;
    if (num === 0) { return "0/1"; }
    var g = gcd(num, den);
    return (num / g) + "/" + (den / g);
  }

  function midiOf(note) {
    var p = note.Pitch || note.pitch;
    if (!p) { return null; }
    var fundamental = (p.FundamentalNote !== undefined) ? p.FundamentalNote : p.fundamentalNote;
    var octave = (p.Octave !== undefined) ? p.Octave : p.octave;
    var alter = (p.AccidentalHalfTones !== undefined) ? p.AccidentalHalfTones : 0;
    return fundamental + alter + (octave + 4) * 12;
  }

  function elementsFor(graphicalNote) {
    var out = [];
    try {
      if (typeof graphicalNote.getNoteheadSVGs === "function") {
        var heads = graphicalNote.getNoteheadSVGs();
        if (heads && heads.length) { for (var i = 0; i < heads.length; i++) { out.push(heads[i]); } }
      }
      if (!out.length && typeof graphicalNote.getSVGGElement === "function") {
        var g = graphicalNote.getSVGGElement();
        if (g) { out.push(g); }
      }
    } catch (e) { /* leave empty */ }
    return out;
  }

  function buildMaps() {
    noteMap = {}; measureBoxes = [];
    var zoom = osmd.zoom || 1;
    var unit = 10 * zoom;
    var list = osmd.GraphicSheet.MeasureList;
    for (var m = 0; m < list.length; m++) {
      var boxes = [];
      for (var s = 0; s < list[m].length; s++) {
        var gm = list[m][s];
        if (!gm) { continue; }
        var ps = gm.PositionAndShape;
        if (ps && ps.AbsolutePosition) {
          boxes.push({ x: ps.AbsolutePosition.x * unit, y: (ps.AbsolutePosition.y + ps.BorderTop) * unit,
                       w: ps.Size.width * unit, h: (ps.BorderBottom - ps.BorderTop) * unit });
        }
        var entries = gm.staffEntries || [];
        for (var e = 0; e < entries.length; e++) {
          var voices = entries[e].graphicalVoiceEntries || [];
          for (var v = 0; v < voices.length; v++) {
            var notes = voices[v].notes || [];
            for (var n = 0; n < notes.length; n++) {
              var gn = notes[n];
              var src = gn.sourceNote;
              if (!src || (src.isRest && src.isRest())) { continue; }
              var midi = midiOf(src);
              if (midi === null) { continue; }
              var ts = src.voiceEntry ? (src.voiceEntry.Timestamp || src.voiceEntry.timestamp) : null;
              if (!ts) { continue; }
              var key = m + ":" + midi + ":" + fractionKey(ts);
              var els = elementsFor(gn);
              // For a chord the group covers every notehead; pick this note's own head when we can.
              if (els.length > 1 && notes.length === els.length) { els = [els[n]]; }
              (noteMap[key] = noteMap[key] || []).push.apply(noteMap[key], els);
            }
          }
        }
      }
      measureBoxes.push(boxes);
    }
  }

  function paint(el, color) {
    if (!el) { return; }
    el.setAttribute("fill", color);
    el.setAttribute("stroke", color);
    var parts = el.querySelectorAll ? el.querySelectorAll("path, rect, text") : [];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].getAttribute("fill") !== "none") { parts[i].setAttribute("fill", color); }
      parts[i].setAttribute("stroke", color);
    }
  }

  function colorOf(key) {
    if (current.indexOf(key) >= 0) { return COLORS.current; }
    return COLORS[marked[key]] || COLORS.plain;
  }

  function repaint(key) {
    var els = noteMap[key];
    if (!els) { return; }
    for (var i = 0; i < els.length; i++) { paint(els[i], colorOf(key)); }
  }

  function scrollTo(key) {
    var els = noteMap[key];
    if (!els || !els.length) { return; }
    var r = els[0].getBoundingClientRect();
    var top = r.top + window.scrollY;
    var view = window.innerHeight;
    if (r.top < 60 || r.bottom > view - 110) {
      window.scrollTo({ top: Math.max(0, top - view * 0.3), behavior: window.notationReducedMotion ? "auto" : "smooth" });
    }
  }

  var api = {
    load: function (xml, zoom) {
      var container = document.getElementById("score");
      var message = document.getElementById("message");
      container.innerHTML = ""; message.style.display = "none";
      marked = {}; current = []; dimmed = [];
      osmd = new opensheetmusicdisplay.OpenSheetMusicDisplay(container, {
        backend: "svg", autoResize: false, drawTitle: false, drawSubtitle: false, drawComposer: false, drawLyricist: false,
        drawPartNames: false, drawPartAbbreviations: false, drawMeasureNumbers: true, autoBeam: true, followCursor: false,
        drawFingerings: true, newSystemFromXML: false, pageFormat: "Endless"
      });
      return osmd.load(xml).then(function () {
        osmd.zoom = zoom || 1.0;
        osmd.render();
        buildMaps();
        var info = { type: "loaded", measures: measureBoxes.length, notes: Object.keys(noteMap).length };
        post(info);
        return info;
      }).catch(function (error) {
        message.textContent = "This score could not be drawn: " + (error && error.message ? error.message : error);
        message.style.display = "block";
        var info = { type: "error", message: String(error && error.message ? error.message : error) };
        post(info);
        return info;
      });
    },
    hasKeys: function (keys) {
      var missing = [];
      for (var i = 0; i < keys.length; i++) { if (!noteMap[keys[i]]) { missing.push(keys[i]); } }
      return missing;
    },
    setCurrent: function (keys, scroll) {
      var old = current;
      current = keys || [];
      for (var i = 0; i < old.length; i++) { repaint(old[i]); }
      for (var j = 0; j < current.length; j++) { repaint(current[j]); }
      if (scroll !== false && current.length) { scrollTo(current[0]); }
    },
    mark: function (keys, state) {
      for (var i = 0; i < keys.length; i++) {
        if (state === "clear") { delete marked[keys[i]]; } else { marked[keys[i]] = state; }
        repaint(keys[i]);
      }
    },
    clearMarks: function () {
      var keys = Object.keys(marked);
      marked = {};
      for (var i = 0; i < keys.length; i++) { repaint(keys[i]); }
    },
    // Fades every measure outside first...last so the practice passage stands out.
    setRange: function (first, last) {
      var container = document.getElementById("score");
      for (var i = 0; i < dimmed.length; i++) { dimmed[i].remove(); }
      dimmed = [];
      if (first === null || first === undefined) { return; }
      for (var m = 0; m < measureBoxes.length; m++) {
        if (m >= first && m <= last) { continue; }
        for (var b = 0; b < measureBoxes[m].length; b++) {
          var box = measureBoxes[m][b];
          var d = document.createElement("div");
          d.className = "dim";
          d.style.left = (box.x + 8) + "px"; d.style.top = (box.y + 4 - 14) + "px";
          d.style.width = box.w + "px"; d.style.height = (box.h + 28) + "px";
          container.appendChild(d); dimmed.push(d);
        }
      }
    },
    scrollToMeasure: function (m) {
      var boxes = measureBoxes[m];
      if (boxes && boxes.length) { window.scrollTo({ top: Math.max(0, boxes[0].y - 40), behavior: "auto" }); }
    },
    keys: function () { return Object.keys(noteMap); }
  };

  window.notation = api;
  document.addEventListener("click", function (event) {
    var y = event.pageY - 4, x = event.pageX - 8;
    for (var m = 0; m < measureBoxes.length; m++) {
      for (var b = 0; b < measureBoxes[m].length; b++) {
        var box = measureBoxes[m][b];
        if (x >= box.x && x <= box.x + box.w && y >= box.y - 14 && y <= box.y + box.h + 14) { post({ type: "measureTapped", measure: m }); return; }
      }
    }
  });
  post({ type: "ready" });
})();

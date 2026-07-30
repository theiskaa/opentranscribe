"use client";

import { useEffect, useRef } from "react";

const VERT = `
attribute vec2 a;
void main() { gl_Position = vec4(a, 0.0, 1.0); }
`;

const FRAG = `
precision highp float;

uniform vec2 u_res;
uniform float u_time;
uniform float u_cell;

float bayer2(vec2 a) {
  a = floor(a);
  return fract(a.x * 0.5 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer4(a); }

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.31, 289.17))) * 43758.5453); }

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float s = 0.0, a = 0.5;
  for (int i = 0; i < 3; i++) {
    s += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return s;
}

void main() {
  vec2 block = floor(gl_FragCoord.xy / u_cell);
  vec2 px = block * u_cell;
  vec2 q = vec2(px.x, u_res.y - px.y) / u_res.x;

  float t = u_time * 0.02;

  float d = distance(q, vec2(0.5, 0.32));
  float glow = 1.0 - smoothstep(0.05, 0.62, d);
  glow = glow * glow * (3.0 - 2.0 * glow);

  float breathe = 0.82 + 0.34 * (fbm(q * 2.6 + vec2(t, -t * 0.6)) - 0.5);
  float tone = glow * 0.40 * breathe;

  float thr = mix(bayer8(block), hash(block), 0.06);
  float lit = step(thr, tone);
  float shade = 0.18 + 0.16 * glow;

  gl_FragColor = vec4(vec3(shade) * lit, 1.0);
}
`;

function compile(gl: WebGLRenderingContext, type: number, src: string) {
  const sh = gl.createShader(type)!;
  gl.shaderSource(sh, src);
  gl.compileShader(sh);
  return sh;
}

export default function Background() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const maybeCanvas = canvasRef.current;
    const maybeWrap = wrapRef.current;
    if (!maybeCanvas || !maybeWrap) return;
    const canvas = maybeCanvas;
    const wrap = maybeWrap;
    const maybeGl = canvas.getContext("webgl", { antialias: false, alpha: false });
    if (!maybeGl) return;
    const gl = maybeGl;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    const program = gl.createProgram()!;
    gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, VERT));
    gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, FRAG));
    gl.linkProgram(program);
    gl.useProgram(program);

    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(program, "a");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    const uRes = gl.getUniformLocation(program, "u_res");
    const uTime = gl.getUniformLocation(program, "u_time");
    const uCell = gl.getUniformLocation(program, "u_cell");

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const cell = dpr * 2;
    gl.uniform1f(uCell, cell);

    let raf = 0;
    let shown = false;
    let faded = false;

    function draw(t: number) {
      gl.uniform1f(uTime, t);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      if (!shown) {
        shown = true;
        canvas.style.opacity = "1";
      }
    }

    function resize() {
      const w = Math.max(1, Math.floor(canvas.clientWidth * dpr));
      const h = Math.max(1, Math.floor(canvas.clientHeight * dpr));
      canvas.width = w;
      canvas.height = h;
      gl.viewport(0, 0, w, h);
      gl.uniform2f(uRes, w, h);
      if (reduced) draw(0);
    }

    function frame(now: number) {
      if (!faded) draw(now * 0.001);
      if (!document.hidden) raf = requestAnimationFrame(frame);
    }

    function onVisible() {
      if (!document.hidden) {
        cancelAnimationFrame(raf);
        raf = requestAnimationFrame(frame);
      }
    }

    function onScroll() {
      const h = window.innerHeight || 1;
      const o = Math.max(0, 1 - window.scrollY / (h * 0.8));
      wrap.style.opacity = String(o);
      faded = o <= 0;
    }

    resize();
    onScroll();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    window.addEventListener("scroll", onScroll, { passive: true });

    if (!reduced) {
      document.addEventListener("visibilitychange", onVisible);
      raf = requestAnimationFrame(frame);
    }

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      window.removeEventListener("scroll", onScroll);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, []);

  return (
    <div aria-hidden ref={wrapRef} className="pointer-events-none fixed inset-0 z-0">
      <canvas
        ref={canvasRef}
        className="block h-full w-full"
        style={{ opacity: 0, transition: "opacity 900ms var(--ease-out)" }}
      />
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background: "linear-gradient(to bottom, transparent 58%, #000 92%)",
        }}
      />
    </div>
  );
}

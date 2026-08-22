import type { ReactNode } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

function textOf(children: ReactNode): string {
  if (typeof children === "string") return children;
  if (Array.isArray(children)) return children.map(textOf).join("");
  if (children && typeof children === "object" && "props" in children) {
    return textOf((children.props as { children?: ReactNode }).children);
  }
  return "";
}

function Release({ children }: { children?: ReactNode }) {
  const text = textOf(children);
  const split = text.indexOf(" - ");
  const version = split === -1 ? text : text.slice(0, split);
  const date = split === -1 ? null : text.slice(split + 3);
  return (
    <h2 className="t-title mt-20 border-t border-line pt-8 first:mt-0 first:border-0 first:pt-0">
      {version}
      {date ? <span className="t-subhead ml-3">{date}</span> : null}
    </h2>
  );
}

const components = {
  h2: Release,
  h3: (props: { children?: ReactNode }) => (
    <h3 className="t-body mt-10 font-semibold">{props.children}</h3>
  ),
  p: (props: { children?: ReactNode }) => (
    <p className="t-body mt-6 text-ink-2">{props.children}</p>
  ),
  ul: (props: { children?: ReactNode }) => (
    <ul className="mt-6 list-disc space-y-4 border-t border-line pl-5 pt-6">{props.children}</ul>
  ),
  ol: (props: { children?: ReactNode }) => (
    <ol className="mt-6 list-decimal space-y-4 pl-5">{props.children}</ol>
  ),
  li: (props: { children?: ReactNode }) => (
    <li className="t-body pl-1 text-ink-2 marker:text-line">{props.children}</li>
  ),
  a: (props: { href?: string; children?: ReactNode }) => (
    <a
      href={props.href}
      target="_blank"
      rel="noreferrer"
      className="text-ink underline decoration-line underline-offset-4 transition-colors duration-200 hover:decoration-ink"
    >
      {props.children}
    </a>
  ),
  strong: (props: { children?: ReactNode }) => (
    <strong className="font-semibold text-ink">{props.children}</strong>
  ),
  code: (props: { children?: ReactNode }) => (
    <code className="rounded border border-line bg-ink/[0.06] px-1.5 py-0.5 text-[0.92em] text-ink">
      {props.children}
    </code>
  ),
  hr: () => <hr className="mt-12 border-line" />,
  table: (props: { children?: ReactNode }) => (
    <div className="mt-6 overflow-x-auto">
      <table className="w-full border-collapse">{props.children}</table>
    </div>
  ),
  th: (props: { children?: ReactNode }) => (
    <th className="t-footnote border-b border-line py-3 pr-6 text-left font-semibold text-ink">
      {props.children}
    </th>
  ),
  td: (props: { children?: ReactNode }) => (
    <td className="t-footnote border-b border-line py-3 pr-6 align-top">{props.children}</td>
  ),
};

export default function Markdown({ children }: { children: string }) {
  return (
    <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
      {children}
    </ReactMarkdown>
  );
}

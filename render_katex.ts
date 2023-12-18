import { opendir, open, FileHandle, writeFile, mkdir } from 'node:fs/promises'
import { getHashes, createHash } from 'node:crypto'
import { Dirent } from 'node:fs'
import _path from 'node:path'

import katex from 'katex'

const hashAlgo = getHashes()[0]

const mathRegexp = /!LATEX(?<inline>~\s+)?(.+?(?=!LATEX!))!LATEX!/sg

function replaceRegex(_str: string, inline: string|undefined, latex: string) {
  const hasher = createHash(hashAlgo)
  hasher.update(latex)
  const latexHash = hasher.digest('hex')

  if (inline) {
    return `{{< katex-inline "${latexHash}" >}}`
  } else {
    return `{{< katex-block "${latexHash}" >}}`
  }
}

function katexPathToHugo(path: _path.ParsedPath) {
  if (path.root) {
    return path
  }

  let ascendPath = path
  let accumPath: string[] = []
  while (ascendPath.dir && ascendPath.dir != '.') {
    accumPath.push(ascendPath.base)
    ascendPath = _path.parse(ascendPath.dir)
  }

  if (ascendPath.base != 'katex') {
    return path
  }

  return _path.parse(_path.join('content', ...accumPath.reverse()))
}

function escapeRendered(rendered: string) {
  let escaped = rendered.replaceAll('{', '&#123;')
  return escaped.replaceAll('}', '&#125;')
}

const renderInline = (() => {
  const cache: Map<string, string> = new Map()
  return async (latex: string) => {
    const hasher = createHash(hashAlgo)
    hasher.update(latex)
    const latexHash = hasher.digest('hex')

    if (cache.has(latexHash)) {
      return;
    }

    const rendered = escapeRendered(katex.renderToString(latex))
    cache.set(latexHash, rendered)

    const outputPath = `./layouts/partials/rendered-latex/${latexHash}-inline.html`
    await writeFile(outputPath, rendered)
  }
})()

const renderBlock = (() => {
  const cache: Map<string, string> = new Map()
  return async (latex: string) => {
    const hasher = createHash(hashAlgo)
    hasher.update(latex)
    const latexHash = hasher.digest('hex')

    if (cache.has(latexHash)) {
      return;
    }

    const rendered = escapeRendered(katex.renderToString(latex, { displayMode: true }))
    cache.set(latexHash, rendered)

    const outputPath = `./layouts/partials/rendered-latex/${latexHash}-block.html`
    await writeFile(outputPath, rendered)
  }
})()

async function renderFile(file: FileHandle, path: _path.ParsedPath) {
  let content = (await file.readFile()).toString('utf8')
  const matches = [...content.matchAll(mathRegexp)]

  content = content.replaceAll(mathRegexp, replaceRegex)

  const outputPath = katexPathToHugo(path)
  await mkdir(outputPath.dir, { recursive: true })
  await writeFile(_path.join(outputPath.dir, outputPath.base), content)

  for (const [_, inline, latex] of matches) {
    if (inline) {
      await renderInline(latex)
    } else {
      await renderBlock(latex)
    }
  }
}

async function renderDir(dirent: Dirent) {
  if (dirent.isDirectory()) {
    const dir = await opendir(_path.join(dirent.path, dirent.name))
    for await (const dirent of dir) {
      await renderDir(dirent)
    }
  } else if (dirent.isFile()) {
    const path = _path.parse(_path.join(dirent.path, dirent.name))
    const file = await open(_path.join(path.dir, path.base))
    await renderFile(file, path)
    await file.close()
  }
}

async function main() {
  await mkdir('./layouts/partials/rendered-latex', { recursive: true })
  const dir = await opendir('./katex')
  for await (const dirent of dir) {
    await renderDir(dirent)
  }
}

(async () => {
  await main()
})()

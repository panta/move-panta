import fs, move

# Function which produces the text content of a file
read = ^(path, encoding: "utf8") { fs.readFileSync(path, encoding) }

# Function which enumerate all files in `dir` matching a pattern
enumerateDirectory = ^(path, deep:true, pattern: /.*/, apply, parentPath:''){
  fs.readdirSync(path).forEach(^(name) {
    entryPath = path+'/'+name
    if (deep && (fs.statSync entryPath).isDirectory()) {
      enumerateDirectory { path:entryPath, deep:true, pattern:pattern,
                           apply:apply, parentPath: parentPath + name + '/' }
    } else if (pattern.test name) {
      apply parentPath + name
    }
  })
}

# Variables holding the final output and the browser template
output = ''
browserTemplate = read { path: __dirname + '/template.js' }

# Static includes
browserTemplate.forEachMatch(/\/\*#include\s+(.+)\*\//gm, ^(m) {
  content = read { path:  __dirname + '/' + m[1] }
  browserTemplate = browserTemplate.substr(0, m.index) +
      content +
      browserTemplate.substr(m.index + m[0].length)
})

# %VERSION% -> "x.x.x"
browserTemplate = browserTemplate.replace(/%VERSION%/g, JSON move.version())

# Source directory
sourceDir = __dirname + '/../lib'

# Source files to exclude from the browser library
exclude = [
  /^cli\//,
]

# Collect all sources into `output`
enumerateDirectory { path: sourceDir,
                  pattern: /\.(js|move|mv)$/,
                    apply: ^(filename) {
  for (i=0; i < exclude.length; ++i)
    if (exclude[i].test filename)
      return

  # Read text source
  source = read { path: sourceDir + '/' + filename }

  # Pass Move sources through the Move compiler
  if (filename.match(/\.(?:mv|move)$/))
    source = move.compile { source: source, filename: filename }

  # Derive "module name" from filename
  name = /^(.+)\.[^\.]+$/.exec(filename)[1]

  # Wrap in module declaration
  source = 'modules[' + JSON.stringify(name) + '] = module = {'+
             'id: ' + JSON.stringify(name) + ','+
             'exports: {},'+
             'block: '+
                'function (exports, require, module, __filename, __dirname) {'+
                  source + '\n}'+
           '};\n'

  # Append source to output
  output += source
}}

# Wrap the combined sources in the browser.js template
output = browserTemplate.replace(/\/\/\s*%CONTENT%.*/, output)

# Run through UglifyJS if available
if (1) try {
  import uglifyjs = 'uglify-js'
  ast = uglifyjs.parser.parse(output)
  ast = uglifyjs.uglify.ast_mangle(ast)
  ast = uglifyjs.uglify.ast_squeeze(ast)
  output = uglifyjs.uglify.gen_code(ast)
} catch (e) { console.error(e); } else {
  output = '/*jslint devel: true, browser: true, evil: true, forin: true, es5: true */' + output;
}

# Write output to /web/move.js
fs.writeFileSync(__dirname + '/../web/move.js', output)

#print output.substr(0, 500)+'\n...\n\nOK!'

if exists('b:current_syntax')
  finish
end

syntax clear

let b:current_syntax = 'qf'

syn match qfError '^E ' nextgroup=qfPath
syn match qfWarning '^W ' nextgroup=qfPath
syn match qfHint '^H ' nextgroup=qfPath
syn match qfInfo '^I ' nextgroup=qfPath
syn match qfPath '^\(E \|W \|H \|I \)\@![^:]\+' nextgroup=qfPosition

syn match qfPath '[^:]\+' nextgroup=qfPosition contained
syn match qfPosition ':[0-9]\+\(:[0-9]\+\)\?' contained

hi def link qfPath Directory
hi def link qfPosition Number

hi def link qfError DiagnosticError
hi def link qfWarning DiagnosticWarn
hi def link qfInfo DiagnosticInfo
hi def link qfHint DiagnosticHint
